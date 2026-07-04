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
  };
}
