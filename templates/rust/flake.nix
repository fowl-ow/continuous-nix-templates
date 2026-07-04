{
  description = "Rust project (follows central nixpkgs)";

  inputs = {
    continuous-nix-templates.url = "github:fowl-ow/continuous-nix-templates";
    nixpkgs.follows = "continuous-nix-templates/nixpkgs";
    rust-overlay.follows = "continuous-nix-templates/rust-overlay";
    # required even without web processes: the bundle's stack module resolves
    # this against *this* flake's inputs
    process-compose-flake.follows = "continuous-nix-templates/process-compose-flake";
  };

  outputs =
    inputs@{
      flake-parts,
      continuous-nix-templates,
      ...
    }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        continuous-nix-templates.flakeModules.default
      ];

      systems = [
        "aarch64-darwin"
        "x86_64-linux"
      ];

      perSystem = _: {
        lang.rust.enable = true;
        # lang.rust.channel = "nightly";   # uncomment for nightly
      };
    };
}
