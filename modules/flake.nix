{ inputs, ... }:
{

  imports = [
    inputs.flake-parts.flakeModules.modules
  ];

  systems = [
    "aarch64-darwin"
    "x86_64-linux"
  ];

  flake = {
    # One bundle with every capability module; consumers import it and flip
    # enable switches (web.enable, lang.rust.enable, ...). Because every
    # effect is enable-gated, the same files can also be auto-imported into
    # THIS repo's own flake (import-tree at the flake root) without
    # colliding — the repo itself just gets an empty default dev shell.
    flakeModules.default = inputs.import-tree [
      ./core
      ./lang
      ./stack
    ];

    # starters for `nix flake init -t github:fowl-ow/continuous-nix-templates#<name>`
    templates = {
      rust = {
        path = ../templates/rust;
        description = "Rust project (rust-overlay toolchain, central nixpkgs)";
        welcomeText = ''
          # Next steps

          1. Enable + configure lang.rust in flake.nix
          2. Add flake.nix and .envrc to git
          3. `direnv allow`
        '';
      };
      php = {
        path = ../templates/php;
        description = "PHP web project (php-fpm + Apache behind the global web-stack Caddy)";
        welcomeText = ''
          # Next steps

          1. Enable + configure web in flake.nix (hostname, php version)
          2. Add flake.nix and .envrc to git
          3. `direnv allow`
          4. `up` (detached; `attach` for the TUI, `down` to stop)
        '';
      };
      python = {
        path = ../templates/python;
        description = "Python project (uv)";
        welcomeText = ''
          # Next steps

          1. Add flake.nix and .envrc to git
          2. `direnv allow`
          3. `uv sync` to install dependencies (including ruff and pyright)
        '';
      };
    };
  };
}
