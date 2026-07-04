#
# Rust toolchain via rust-overlay (rustc, cargo, rust-src, rust-analyzer).
# Uses its own nixpkgs instance so the overlay doesn't leak into the pkgs
# other capabilities see.
#
{ lib, inputs, ... }:
{
  perSystem =
    { config, system, ... }:
    let
      cfg = config.lang.rust;
    in
    {
      options.lang.rust = {
        enable = lib.mkEnableOption "the Rust toolchain";

        channel = lib.mkOption {
          type = lib.types.enum [
            "stable"
            "nightly"
          ];
          default = "stable";
          description = "Rust channel to use";
        };
      };

      config = lib.mkIf cfg.enable (
        let
          pkgs = import inputs.nixpkgs {
            inherit system;
            overlays = [ inputs.rust-overlay.overlays.default ];
          };

          extraComponents = [
            "rust-src"
            "rust-analyzer"
          ];

          rustToolchain =
            if cfg.channel == "stable" then
              pkgs.rust-bin.stable.latest.default.override {
                extensions = extraComponents;
              }
            else
              pkgs.rust-bin.selectLatestNightlyWith (
                toolchain:
                toolchain.default.override {
                  extensions = extraComponents;
                }
              );
        in
        {
          shell.packages = [ rustToolchain ];

          shell.hook = ''
            echo "🦀 Rust dev shell (${cfg.channel})"
            echo "$(rustc --version)"
          '';
        }
      );
    };
}
