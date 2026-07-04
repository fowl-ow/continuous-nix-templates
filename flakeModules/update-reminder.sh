# Sourced by the template .envrc after `use flake` (runs on every directory
# entry). Warns when the locked continuous-nix-templates revision is behind
# upstream HEAD. Upstream is queried at most once a day (cached in .direnv);
# the comparison itself is local and offline-safe.
_tmpl_cache=".direnv/template-upstream.head"
if [ -n "${TEMPLATE_UPSTREAM_URL:-}" ] && [ -n "${TEMPLATE_LOCKED_REV:-}" ]; then
  mkdir -p .direnv
  if [ ! -f "$_tmpl_cache" ] || [ -n "$(find "$_tmpl_cache" -mmin +1440 2>/dev/null)" ]; then
    git ls-remote "$TEMPLATE_UPSTREAM_URL" HEAD 2>/dev/null | cut -f1 >"$_tmpl_cache" || true
  fi
  _tmpl_remote=$(cat "$_tmpl_cache" 2>/dev/null)
  if [ -n "$_tmpl_remote" ] && [ "$_tmpl_remote" != "$TEMPLATE_LOCKED_REV" ]; then
    echo "⬆ continuous-nix-templates is behind upstream — run: nix flake update continuous-nix-templates"
  fi
  unset _tmpl_remote
fi
unset _tmpl_cache
