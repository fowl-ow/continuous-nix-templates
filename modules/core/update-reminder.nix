#
# Update reminder for template consumers. The dev shell exports
# TEMPLATE_DIRENV_HOOK pointing at a small script; the templates' .envrc
# executes it after `use flake`, so it runs on every directory entry and
# warns when the locked continuous-nix-templates revision is behind
# upstream HEAD. Upstream is queried at most once an hour (cached in
# .direnv); the comparison itself is local and offline-safe.
#
{ inputs, ... }:
{
  perSystem =
    { pkgs, ... }:
    let
      # writeShellApplication: shellcheck runs at build time, runtime deps
      # are pinned instead of taken from whatever PATH direnv has
      reminder = pkgs.writeShellApplication {
        name = "template-update-reminder";
        runtimeInputs = [
          pkgs.git
          pkgs.coreutils
          pkgs.findutils
        ];
        text = ''
          [ -n "''${TEMPLATE_UPSTREAM_URL:-}" ] || exit 0
          [ -n "''${TEMPLATE_LOCKED_REV:-}" ] || exit 0
          cache=".direnv/template-upstream.head"
          mkdir -p .direnv
          if [ ! -f "$cache" ] || [ -n "$(find "$cache" -mmin +60 2>/dev/null)" ]; then
            git ls-remote "$TEMPLATE_UPSTREAM_URL" HEAD 2>/dev/null | cut -f1 >"$cache" || true
          fi
          remote=$(cat "$cache" 2>/dev/null || true)
          if [ -n "$remote" ] && [ "$remote" != "$TEMPLATE_LOCKED_REV" ]; then
            echo "⬆ continuous-nix-templates is behind upstream — run: nix flake update continuous-nix-templates"
          fi
        '';
      };
    in
    {
      shell.env = {
        TEMPLATE_DIRENV_HOOK = "${reminder}/bin/template-update-reminder";
        TEMPLATE_UPSTREAM_URL = "https://github.com/fowl-ow/continuous-nix-templates";
        # the consumer's locked revision, baked in at eval time (re-baked when
        # flake.lock changes); empty for path:/dirty inputs
        TEMPLATE_LOCKED_REV = (inputs.continuous-nix-templates or { }).rev or "";
      };
    };
}
