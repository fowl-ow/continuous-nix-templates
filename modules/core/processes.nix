#
# Generic process runner: capability modules declare long-running dev
# processes in `processes`; this module turns them into a
# process-compose app (`nix run .#up`) plus `up`/`down`/`attach` shell
# commands. Control goes via a per-project unix socket instead of the TCP
# server (which defaults to 127.0.0.1:8080 and collides with e.g.
# OrbStack); this also enables background runs:
#   up      start detached
#   attach  view the TUI of a detached run
#   down    stop everything
#
{ lib, inputs, ... }:
{
  imports = [ inputs.process-compose-flake.flakeModule ];

  perSystem =
    { config, pkgs, ... }:
    let
      cfg = config.processes;

      # process-compose control socket; directly in /tmp because the server
      # binds it before any process could `mkdir -p` a run dir, and unix
      # socket paths are limited to ~104 chars
      pcSocket = "/tmp/processes-${cfg.id}.sock";

      # Quick commands, on PATH only while inside this project's dev shell
      # (direnv adds/removes them with the directory). The socket is baked
      # in so they always target this project's instance.
      upCmd = pkgs.writeShellScriptBin "up" ''
        exec ${config.process-compose."up".outputs.package}/bin/up -D "$@"
      '';
      downCmd = pkgs.writeShellScriptBin "down" ''
        exec ${pkgs.process-compose}/bin/process-compose down -U -u ${pcSocket} "$@"
      '';
      attachCmd = pkgs.writeShellScriptBin "attach" ''
        exec ${pkgs.process-compose}/bin/process-compose attach -U -u ${pcSocket} "$@"
      '';
    in
    {
      options.processes = {
        id = lib.mkOption {
          type = lib.types.str;
          description = "Instance id for the control socket path (usually the project hostname)";
        };

        processes = lib.mkOption {
          type = lib.types.attrsOf lib.types.anything;
          default = { };
          description = "process-compose process definitions contributed by capability modules";
        };
      };

      config = lib.mkIf (cfg.processes != { }) {
        process-compose."up" = {
          cli.options = {
            use-uds = true;
            unix-socket = pcSocket;
          };
          settings.processes = cfg.processes;
        };

        shell.packages = [
          pkgs.process-compose
          upCmd
          downCmd
          attachCmd
        ];

        # lets a bare `process-compose attach`/`down` find this instance too
        shell.env.PC_SOCKET_PATH = pcSocket;
      };
    };
}
