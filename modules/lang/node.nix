#
# Node.js + pnpm for frontend builds.
#
{ lib, ... }:
{
  perSystem =
    { config, pkgs, ... }:
    let
      cfg = config.lang.node;
    in
    {
      options.lang.node = {
        enable = lib.mkEnableOption "Node.js (with pnpm)";

        package = lib.mkOption {
          type = lib.types.package;
          default = pkgs.nodejs_24;
          defaultText = "pkgs.nodejs_24";
          description = "Node.js package for the frontend build";
        };

        # pnpm majors are picky about lockfileVersion — pin (pkgs.pnpm_10, ...)
        # to match the project's pnpm-lock.yaml; null if the project doesn't
        # use pnpm.
        pnpm = lib.mkOption {
          type = lib.types.nullOr lib.types.package;
          default = pkgs.pnpm;
          defaultText = "pkgs.pnpm";
          description = "pnpm package for the frontend workflow, or null to omit";
        };
      };

      config = lib.mkIf cfg.enable {
        shell.packages = [ cfg.package ] ++ lib.optional (cfg.pnpm != null) cfg.pnpm;
      };
    };
}
