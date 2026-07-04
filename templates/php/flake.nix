{
  description = "PHP web project (follows central nixpkgs; served via the global web-stack Caddy)";

  inputs = {
    continuous-nix-templates.url = "github:fowl-ow/continuous-nix-templates";
    nixpkgs.follows = "continuous-nix-templates/nixpkgs";
    # required: the capability modules resolve this against *this* flake's inputs
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

      perSystem = { pkgs, ... }: {
        stack.php = {
          enable = true;
          hostname = "myproject.internal";
          # docroot = "public";                     # default
          # port    = 8501;                         # default: hash-derived from hostname
          # env     = { TYPO3_CONTEXT = "Development"; };
        };

        lang.php.package = pkgs.php83;
        # lang.node.pnpm  = pkgs.pnpm_10;           # pin pnpm major to the lockfileVersion
        # lang.node.enable = false;                 # no frontend build

        # extra tools for this project's dev shell:
        # shell.packages = [ pkgs.mailpit ];
      };
    };
}
