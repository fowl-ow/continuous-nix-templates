#
# Reminds when the locked continuous-nix-templates revision is behind
# upstream HEAD. Runs as a sync.checks program on every shell entry;
# upstream is queried at most once per hour (cached in .direnv), the
# comparison itself is local and offline-safe.
#
{ inputs, ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      sync.checks = [
        (pkgs.writeShellApplication {
          name = "check-template-upstream";
          runtimeInputs = builtins.attrValues {
            inherit (pkgs)
              git
              coreutils
              findutils
              ;
          };

          text = /* sh */ ''
            locked="${(inputs.continuous-nix-templates or { }).rev or ""}"
            [ -n "$locked" ] || exit 0
            cache=".direnv/template-upstream.head"
            mkdir -p .direnv
            if [ ! -f "$cache" ] || [ -n "$(find "$cache" -mmin +60 2>/dev/null)" ]; then
              git ls-remote "https://github.com/fowl-ow/continuous-nix-templates" HEAD 2>/dev/null | cut -f1 >"$cache" || true
            fi
            remote=$(cat "$cache" 2>/dev/null || true)
            if [ -n "$remote" ] && [ "$remote" != "$locked" ]; then
              echo "⬆ continuous-nix-templates is behind upstream — run: nix flake update continuous-nix-templates"
            fi
          '';
        })
      ];
    };
}
