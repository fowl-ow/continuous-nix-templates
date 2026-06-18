{
  description = "Rust project (follows central nixpkgs)";

  inputs = {
    continuous-nix-templates.url = "github:fowl-ow/continuous-nix-templates";
    nixpkgs.follows = "continuous-nix-templates/nixpkgs";
    rust-overlay.follows = "continuous-nix-templates/rust-overlay";
    flake-parts.follows = "continuous-nix-templates/flake-parts";
  };

  outputs =
    inputs@{
      flake-parts,
      continuous-nix-templates,
      ...
    }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        continuous-nix-templates.flakeModules.rust
      ];

      systems = [
        "aarch64-darwin"
        "x86_64-linux"
      ];

      perSystem = { config, ... }: {
        # rust.channel = "nightly";   # uncomment for nightly
      };
    };
}
