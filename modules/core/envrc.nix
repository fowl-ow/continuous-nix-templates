#
# Canonical .envrc for template consumers, kept current via sync. The
# copies under templates/ are only the bootstrap for `nix flake init`;
# keep them matching this when editing.
#
_: {
  perSystem =
    { pkgs, ... }:
    {
      sync.files.".envrc" = pkgs.writeText "envrc" /* sh */ ''
        use flake

        # shared template hooks provided by the dev shell (update reminder, ...);
        # no-op when the shell doesn't provide any
        if [ -n "''${CONTINUOUS_NIX_TEMPLATES_HOOK:-}" ] && [ -x "$CONTINUOUS_NIX_TEMPLATES_HOOK" ]; then
          "$CONTINUOUS_NIX_TEMPLATES_HOOK"
        fi
      '';
    };
}
