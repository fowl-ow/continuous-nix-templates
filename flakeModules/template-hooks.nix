#
# Shared template plumbing, imported by every language module (php, rust, ...).
# Exposes env vars that the language modules add to their dev shells; the
# templates' .envrc sources $TEMPLATE_DIRENV_HOOK after `use flake`, so the
# hook runs on every directory entry. Currently: a reminder when the locked
# continuous-nix-templates revision is behind upstream HEAD.
#
{ lib, inputs, ... }:
{
  perSystem = _: {
    options.templateHooks.env = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      description = "Environment variables every language module adds to its dev shell";
    };

    config.templateHooks.env = {
      TEMPLATE_DIRENV_HOOK = "${./update-reminder.sh}";
      TEMPLATE_UPSTREAM_URL = "https://github.com/fowl-ow/continuous-nix-templates";
      # the consumer's locked revision, baked in at eval time (re-baked when
      # flake.lock changes); empty for path:/dirty inputs
      TEMPLATE_LOCKED_REV = (inputs.continuous-nix-templates or { }).rev or "";
    };
  };
}
