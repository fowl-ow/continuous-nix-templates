#
# PHP web project module: pinned PHP dev shell + a process-compose app
# (`nix run .#up`) running php-fpm + per-project Apache. On start it
# registers its hostname with the machine-global Caddy reverse proxy
# (~/.config/nix web-stack module) by dropping a vhost fragment into
# ~/.local/state/web-stack/caddy/vhosts and reloading Caddy; on stop it
# deregisters again. Reachable at https://<hostname> (Caddy terminates TLS).
#
{ lib, inputs, ... }:
{
  imports = [ inputs.process-compose-flake.flakeModule ];

  perSystem =
    { config, pkgs, ... }:
    let
      cfg = config.web;
    in
    {
      options.web = {
        # Base package only — the shared extension set and ini config are
        # layered on via buildEnv below. For a version nixpkgs has dropped
        # (e.g. php81, removed 2025-10), add a flake input pinned to an older
        # nixpkgs revision and pass its php81 here.
        php = lib.mkOption {
          type = lib.types.package;
          default = pkgs.php;
          defaultText = "pkgs.php";
          description = "Base PHP package for this project, e.g. pkgs.php83";
        };

        hostname = lib.mkOption {
          type = lib.types.str;
          description = "Local hostname, e.g. myproject.internal";
        };

        docroot = lib.mkOption {
          type = lib.types.str;
          default = "public";
          description = "Document root, relative to the project root";
        };

        # Hash-derived so the same project gets the same port on every
        # machine with zero bookkeeping. Collisions only matter between
        # simultaneously *running* projects and fail loudly ("address
        # already in use") — set an explicit port on one project then.
        port = lib.mkOption {
          type = lib.types.int;
          default =
            8500
            + lib.mod (lib.fromHexString (
              builtins.substring 0 4 (builtins.hashString "sha256" cfg.hostname)
            )) 1000;
          description = "Private backend port for this project's Apache";
        };

        env = lib.mkOption {
          type = lib.types.attrsOf lib.types.str;
          default = { };
          description = "Environment variables for the dev shell and the services";
        };

        node = lib.mkOption {
          type = lib.types.package;
          default = pkgs.nodejs_24;
          defaultText = "pkgs.nodejs_24";
          description = "Node.js package for the frontend build";
        };
      };

      config =
        let
          php = cfg.php.buildEnv {
            extensions =
              { enabled, all }:
              enabled
              ++ (with all; [
                apcu
                imagick
                xdebug
              ]);
            # xdebug stays off unless XDEBUG_MODE=debug is set at runtime
            extraConfig = ''
              memory_limit = 512M
              xdebug.mode = off
            '';
          };

          # Runtime scratch space (fpm socket, httpd pid). Keyed by hostname,
          # kept short: unix socket paths are limited to ~104 chars.
          runDir = "/tmp/web-stack-${cfg.hostname}";
          fpmSock = "${runDir}/php-fpm.sock";
          # process-compose control socket; directly in /tmp because the
          # server binds it before any process gets to `mkdir -p runDir`
          pcSocket = "/tmp/web-stack-${cfg.hostname}.sock";

          # Quick commands, on PATH only while inside this project's dev
          # shell (direnv adds/removes them with the directory). The socket
          # is baked in so they always target this project's instance.
          upCmd = pkgs.writeShellScriptBin "up" ''
            exec ${config.process-compose."up".outputs.package}/bin/up "$@"
          '';
          downCmd = pkgs.writeShellScriptBin "down" ''
            exec ${pkgs.process-compose}/bin/process-compose down -U -u ${pcSocket} "$@"
          '';
          attachCmd = pkgs.writeShellScriptBin "attach" ''
            exec ${pkgs.process-compose}/bin/process-compose attach -U -u ${pcSocket} "$@"
          '';

          envList = lib.mapAttrsToList (k: v: "${k}=${v}") cfg.env;

          fpmConf = pkgs.writeText "php-fpm-${cfg.hostname}.conf" ''
            [global]
            daemonize = no
            error_log = /dev/stderr

            [www]
            listen = ${fpmSock}
            pm = dynamic
            pm.max_children = 8
            pm.start_servers = 2
            pm.min_spare_servers = 1
            pm.max_spare_servers = 4
            catch_workers_output = yes
            ; keep TYPO3_CONTEXT etc. from the calling environment
            clear_env = no
          '';

          # PROJECT_ROOT is Define'd on the httpd command line from $PWD.
          httpdConf = pkgs.writeText "httpd-${cfg.hostname}.conf" ''
            ServerName ${cfg.hostname}
            Listen 127.0.0.1:${toString cfg.port}
            ServerRoot "${runDir}"
            PidFile "${runDir}/httpd.pid"
            ErrorLog /dev/stderr

            LoadModule mpm_event_module ${pkgs.apacheHttpd}/modules/mod_mpm_event.so
            LoadModule unixd_module ${pkgs.apacheHttpd}/modules/mod_unixd.so
            LoadModule authz_core_module ${pkgs.apacheHttpd}/modules/mod_authz_core.so
            LoadModule authz_host_module ${pkgs.apacheHttpd}/modules/mod_authz_host.so
            LoadModule access_compat_module ${pkgs.apacheHttpd}/modules/mod_access_compat.so
            LoadModule dir_module ${pkgs.apacheHttpd}/modules/mod_dir.so
            LoadModule mime_module ${pkgs.apacheHttpd}/modules/mod_mime.so
            LoadModule log_config_module ${pkgs.apacheHttpd}/modules/mod_log_config.so
            LoadModule env_module ${pkgs.apacheHttpd}/modules/mod_env.so
            LoadModule setenvif_module ${pkgs.apacheHttpd}/modules/mod_setenvif.so
            LoadModule headers_module ${pkgs.apacheHttpd}/modules/mod_headers.so
            LoadModule expires_module ${pkgs.apacheHttpd}/modules/mod_expires.so
            LoadModule deflate_module ${pkgs.apacheHttpd}/modules/mod_deflate.so
            LoadModule filter_module ${pkgs.apacheHttpd}/modules/mod_filter.so
            LoadModule alias_module ${pkgs.apacheHttpd}/modules/mod_alias.so
            LoadModule rewrite_module ${pkgs.apacheHttpd}/modules/mod_rewrite.so
            LoadModule proxy_module ${pkgs.apacheHttpd}/modules/mod_proxy.so
            LoadModule proxy_fcgi_module ${pkgs.apacheHttpd}/modules/mod_proxy_fcgi.so

            TypesConfig ${pkgs.apacheHttpd}/conf/mime.types
            LogFormat "%h %l %u %t \"%r\" %>s %b" common
            CustomLog /dev/stdout common
            DirectoryIndex index.php index.html

            DocumentRoot "''${PROJECT_ROOT}/${cfg.docroot}"
            <Directory "''${PROJECT_ROOT}/${cfg.docroot}">
              Options FollowSymLinks
              AllowOverride All
              Require all granted
            </Directory>

            <FilesMatch "\.php$">
              SetHandler "proxy:unix:${fpmSock}|fcgi://localhost"
            </FilesMatch>

            # Caddy terminates TLS in front of us; make PHP apps detect HTTPS
            SetEnvIf X-Forwarded-Proto https HTTPS=on
          '';
        in
        {
          devShells.default = pkgs.mkShell {
            packages = [
              php
              php.packages.composer
              cfg.node
              pkgs.apacheHttpd
              pkgs.process-compose
              upCmd
              downCmd
              attachCmd
            ];
            # PC_SOCKET_PATH lets down/attach find this project's instance
            env = cfg.env // {
              PC_SOCKET_PATH = pcSocket;
            };
            shellHook = ''
              echo "🐘 PHP ${cfg.php.version} dev shell — https://${cfg.hostname} (backend :${toString cfg.port})"
              echo "   up (foreground TUI) · up -D (background) · down · attach"
            '';
          };

          # control via a per-project unix socket instead of the TCP server
          # (which defaults to 127.0.0.1:8080 and collides with e.g.
          # OrbStack). This also enables background runs:
          #   nix run .#up -- -D        start detached
          #   process-compose attach -U  view the TUI of a detached run
          #   process-compose down -U    stop everything (deregisters vhost)
          process-compose."up".cli.options = {
            use-uds = true;
            unix-socket = pcSocket;
          };

          process-compose."up".settings.processes = {
            php-fpm = {
              command = ''
                mkdir -p ${runDir}
                exec ${php}/bin/php-fpm -F -y ${fpmConf}
              '';
              environment = envList;
            };

            httpd = {
              command = ''
                mkdir -p ${runDir}
                exec ${pkgs.apacheHttpd}/bin/httpd -f ${httpdConf} \
                  -C "Define PROJECT_ROOT $PWD" -DFOREGROUND
              '';
              environment = envList;
              depends_on.php-fpm.condition = "process_started";
            };

            # Registers the vhost with the global Caddy, then idles; the
            # TERM/INT trap deregisters on shutdown (process-compose sends
            # TERM on `down`/Ctrl-C).
            caddy-register = {
              command = ''
                vhost="$HOME/.local/state/web-stack/caddy/vhosts/${cfg.hostname}.caddy"
                caddyfile="$HOME/.local/state/web-stack/Caddyfile"
                reload() {
                  ${pkgs.caddy}/bin/caddy reload --config "$caddyfile" --adapter caddyfile || true
                }
                deregister() {
                  rm -f "$vhost"
                  reload
                }
                trap 'deregister; exit 0' TERM INT
                mkdir -p "$(dirname "$vhost")"
                {
                  echo '${cfg.hostname} {'
                  echo '  tls internal'
                  echo '  reverse_proxy 127.0.0.1:${toString cfg.port}'
                  echo '}'
                } > "$vhost"
                reload
                while :; do sleep 3600 & wait $!; done
              '';
              depends_on.httpd.condition = "process_started";
            };
          };
        };
    };
}
