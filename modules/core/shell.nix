#
# Mergeable dev-shell schema. Capability modules (core/*, lang/*, stack/*)
# contribute packages, env vars and hook lines here; this module is the only
# place that builds an actual mkShell out of them, so any combination of
# capabilities composes without colliding on devShells.default.
#
{ lib, ... }:
{
  perSystem =
    { config, pkgs, ... }:
    {
      options.shell = {
        packages = lib.mkOption {
          type = lib.types.listOf lib.types.package;
          default = [ ];
          description = "Packages available in the project dev shell";
        };

        env = lib.mkOption {
          type = lib.types.attrsOf lib.types.str;
          default = { };
          description = "Environment variables set in the project dev shell";
        };

        hook = lib.mkOption {
          type = lib.types.lines;
          default = "";
          description = "Extra lines run on shell entry (banners, setup)";
        };
      };

      config.devShells.default = pkgs.mkShell {
        packages = config.shell.packages;
        env = config.shell.env;
        shellHook = config.shell.hook;
      };
    };
}
