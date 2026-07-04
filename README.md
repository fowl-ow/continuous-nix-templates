# continuous-nix-templates

Central flake for my project dev environments: composable capability modules
plus starter templates. Projects pin this repo as a flake input, so
improvements reach every project with
`nix flake update continuous-nix-templates` — continuously, not just at
scaffold time.

## Usage

Start a project:

```sh
nix flake init -t github:fowl-ow/continuous-nix-templates#rust
git add flake.nix .envrc
direnv allow
```

A project flake imports the module bundle and enables capabilities:

```nix
perSystem = { pkgs, ... }: {
  stack.php = { enable = true; hostname = "myproject.internal"; };
  lang.php.package = pkgs.php84;
};
```

## Capabilities

- **`lang.rust`** — rust-overlay toolchain with rust-src and rust-analyzer;
  `lang.rust.channel = "stable" | "nightly"`.
- **`lang.php`** — PHP + composer with a shared extension set (apcu,
  imagick, xdebug) and ini defaults; pick the version via `lang.php.package`.
- **`lang.node`** — Node.js + pnpm (pin the pnpm major to your
  lockfileVersion).
- **`stack.php`** — php-fpm + a per-project Apache behind the machine-global
  Caddy reverse proxy: `up` (detached), `attach` (TUI), `down`. Registers
  `https://<hostname>` on start, deregisters on stop; backend port is
  hash-derived from the hostname.
- **sync** — template-owned files (like `.envrc`) kept current in projects:
  `template-check` reports drift on shell entry, `sync` applies updates. Also
  reminds when the pinned template revision is behind upstream.

Capabilities compose freely — one project can enable `lang.rust` and
`stack.php` together; modules merge into a single dev shell.

`stack.php` expects the machine-global web stack (Caddy, MariaDB,
dnsmasq/pf for `*.internal`) from my dotfiles' web-stack
module.
