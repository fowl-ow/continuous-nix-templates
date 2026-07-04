{ inputs, ... }:
{

  imports = [
    inputs.flake-parts.flakeModules.modules
  ];

  systems = [
    "aarch64-darwin"
    "x86_64-linux"
  ];

  # Exported language modules live in ../flakeModules, NOT in modules/:
  # everything under modules/ is auto-imported into THIS repo's own flake
  # (import-tree), and the language modules must only apply to consumer
  # projects — applied here they'd collide on devShells.default and require
  # per-project options like web.hostname.
  flake = {
    flakeModules.rust = ../flakeModules/rust.nix;
    flakeModules.php = ../flakeModules/php.nix;

    # starters for `nix flake init -t github:fowl-ow/continuous-nix-templates#<name>`
    templates = {
      rust = {
        path = ../templates/rust;
        description = "Rust project (rust-overlay toolchain, central nixpkgs)";
      };
      php = {
        path = ../templates/php;
        description = "PHP web project (php-fpm + Apache behind the global web-stack Caddy)";
        welcomeText = ''
          # Next steps

          1. Set hostname + php version in flake.nix
          2. Add flake.nix and .envrc to git
          3. `direnv allow`
          4. `up` (or `up -D` for background, `down` to stop)
        '';
      };
    };
  };
}
