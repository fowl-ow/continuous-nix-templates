{
  lib,
  ...
}:
{
  perSystem =
    { config, pkgs, ... }:
    let
      cfg = config.sync;

      manifest = pkgs.writeText "template-sync-manifest" (
        lib.concatStrings (lib.mapAttrsToList (dest: src: "${dest} ${src}\n") cfg.files)
      );

      checkCmd = pkgs.writeShellApplication {
        name = "template-check";
        runtimeInputs = builtins.attrValues {
          inherit (pkgs)
            coreutils
            diffutils
            ;
        };

        text = /* sh */ ''
          stamp=".direnv/template-sync.applied"
          if [ "$(cat "$stamp" 2>/dev/null)" != "${manifest}" ]; then
            drift=0
            while read -r dest src; do
              if ! cmp -s "$src" "$dest"; then
                echo "$dest is out of date with the template - run: sync"
                drift=1
              fi
            done <${manifest}
            if [ "$drift" -eq 0 ]; then
              mkdir -p .direnv
              echo "${manifest}" >"$stamp"
            fi
          fi

          # always-on checks; each program gates itself and pins its own tools
          ${lib.concatMapStrings (check: ''
            ${lib.getExe check}
          '') cfg.checks}
        '';
      };

      syncCmd = pkgs.writeShellApplication {
        name = "sync";
        runtimeInputs = [ pkgs.coreutils ];
        text = ''
          while read -r dest src; do
            if ! cmp -s "$src" "$dest"; then
              mkdir -p "$(dirname "$dest")"
              install -m 644 "$src" "$dest"
              echo "$dest updated from template"
              fi
          done < ${manifest}
          mkdir -p .direnv
          echo "${manifest}" >.direnv/template-sync.applied
        '';
      };
    in
    {
      options.sync = {
        files = lib.mkOption {
          type = lib.types.attrsOf lib.types.path;
          default = { };
          description = "Fully template-owned files: project-relative path → canonical content (store path)";
        };

        checks = lib.mkOption {
          type = lib.types.listOf lib.types.package;
          default = [ ];
          description = "Drift-check programs run on every shell entry; each must gate itself";
        };
      };
      config = {
        shell.packages = [
          checkCmd
          syncCmd
        ];
        shell.env.CONTINUOUS_NIX_TEMPLATES_HOOK = "${checkCmd}/bin/template-check";
      };
    };
}
