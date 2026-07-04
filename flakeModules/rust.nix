{ lib, inputs, ... }:

let
  rustChannelType = lib.types.enum [
    "stable"
    "nightly"
  ];
in
{
  imports = [ ./template-hooks.nix ];

  perSystem = { config, system, ... }: {
    options.rust.channel = lib.mkOption {
      type = rustChannelType;
      default = "stable";
      description = "Rust channel to use";
    };

    config =
      let
        rustChannel = config.rust.channel;

        pkgs = import inputs.nixpkgs {
          inherit system;
          overlays = [ inputs.rust-overlay.overlays.default ];
        };

        extraComponents = [
          "rust-src"
          "rust-analyzer"
        ];

        rustToolchain =
          if rustChannel == "stable" then
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
        devShells.default = pkgs.mkShell {
          packages = [
            rustToolchain
          ];

          env = config.templateHooks.env;

          shellHook = ''
            echo "🦀 Rust dev shell (${rustChannel})"
            echo "$(rustc --version)"
          '';
        };
      };
  };
}
