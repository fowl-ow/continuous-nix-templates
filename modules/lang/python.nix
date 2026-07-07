#
# Python toolchain (python3, uv).
#
{ lib, ... }:
{
  perSystem =
    { config, pkgs, ... }:
    let
      cfg = config.lang.python;
    in
    {
      options.lang.python = {
        enable = lib.mkEnableOption "the Python toolchain";

        package = lib.mkOption {
          type = lib.types.package;
          default = pkgs.python3;
          defaultText = "pkgs.python3";
          description = "Python package to use";
        };
      };

      config = lib.mkIf cfg.enable {
        shell.packages = [
          cfg.package
          pkgs.uv
        ];

        shell.hook = ''
          echo "🐍 Python dev shell"
          echo "$(python --version)"
          echo "$(uv --version)"
        '';
      };
    };
}
