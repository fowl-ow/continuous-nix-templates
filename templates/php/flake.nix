{
  description = "PHP web project (follows central nixpkgs; served via the global web-stack Caddy)";

  inputs = {
    continuous-nix-templates.url = "github:fowl-ow/continuous-nix-templates";
    nixpkgs.follows = "continuous-nix-templates/nixpkgs";
    flake-parts.follows = "continuous-nix-templates/flake-parts";
    # required: flakeModules.php resolves this against *this* flake's inputs
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
        continuous-nix-templates.flakeModules.php
      ];

      systems = [
        "aarch64-darwin"
        "x86_64-linux"
      ];

      perSystem = { pkgs, ... }: {
        web = {
          hostname = "myproject.internal";
          php = pkgs.php83;
          # docroot = "public";                     # default
          # port    = 8501;                         # default: hash-derived from hostname
          # env     = { TYPO3_CONTEXT = "Development"; };
        };
      };
    };
}
