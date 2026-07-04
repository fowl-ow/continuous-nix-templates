#
# PHP web stack: php-fpm + a per-project Apache, run as `stack` processes
# (`up` / `nix run .#up`). On start it registers its hostname with the
# machine-global Caddy reverse proxy (~/.config/nix php-stack module) by
# dropping a vhost fragment into ~/.local/state/php-stack/caddy/vhosts and
# reloading Caddy; on stop it deregisters again. Reachable at
# https://<hostname> (Caddy terminates TLS).
#
# Enabling this soft-enables lang.php and lang.node (override with
# `lang.node.enable = false;` etc.); the PHP that fpm runs is
# lang.php.finalPackage, so `lang.php.package = pkgs.php84;` picks the
# version.
#
{ lib, ... }:
{
  perSystem =
    { config, pkgs, ... }:
    let
      cfg = config.stack.php;
    in
    {
      options.stack.php = {
        enable = lib.mkEnableOption "the PHP web stack (php-fpm + Apache behind the global Caddy)";

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
      };

      config = lib.mkIf cfg.enable (
        let
          php = config.lang.php.finalPackage;

          # Runtime scratch space (fpm socket, httpd pid). Keyed by hostname,
          # kept short: unix socket paths are limited to ~104 chars.
          runDir = "/tmp/php-stack-${cfg.hostname}";
          fpmSock = "${runDir}/php-fpm.sock";

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
          lang.php.enable = lib.mkDefault true;
          lang.node.enable = lib.mkDefault true;

          process.id = lib.mkDefault cfg.hostname;

          shell = {
            inherit (cfg) env;
            packages = [
              pkgs.apacheHttpd
              pkgs.imagemagick
            ];
            hook = ''
              echo "🐘 PHP ${config.lang.php.package.version} dev shell — https://${cfg.hostname} (backend :${toString cfg.port})"
              echo "   up (detached) · attach (TUI) · down"
            '';
          };

          processes = {
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
                vhost="$HOME/.local/state/php-stack/caddy/vhosts/${cfg.hostname}.caddy"
                caddyfile="$HOME/.local/state/php-stack/Caddyfile"
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
        }
      );
    };
}
