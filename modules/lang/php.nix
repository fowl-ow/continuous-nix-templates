#
# PHP + composer. The base package (lang.php.package, e.g. pkgs.php83) is
# extended with the shared extension set and ini defaults; other modules
# (stack/web) consume the result via the read-only lang.php.finalPackage.
#
{ lib, ... }:
{
  perSystem =
    { config, pkgs, ... }:
    let
      cfg = config.lang.php;
    in
    {
      options.lang.php = {
        enable = lib.mkEnableOption "PHP (with composer)";

        # Base package only — the shared extension set and ini config are
        # layered on via buildEnv below. For a version nixpkgs has dropped
        # (e.g. php81, removed 2025-10), add a flake input pinned to an older
        # nixpkgs revision and pass its php81 here.
        package = lib.mkOption {
          type = lib.types.package;
          default = pkgs.php;
          defaultText = "pkgs.php";
          description = "Base PHP package for this project, e.g. pkgs.php83";
        };

        finalPackage = lib.mkOption {
          type = lib.types.package;
          readOnly = true;
          description = "The PHP package with the shared extensions and ini defaults applied";
        };
      };

      config = {
        lang.php.finalPackage = cfg.package.buildEnv {
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

        shell.packages = lib.mkIf cfg.enable [
          cfg.finalPackage
          cfg.finalPackage.packages.composer
        ];
      };
    };
}
