{ config, lib, ... }: with lib; let
  cfg = config.home.scratch;
  inherit (config.lib.file) mkOutOfStoreSymlink;
in {
  options.home.scratch = with types; {
    enable = mkEnableOption "scratch dir";
    path = mkOption {
      type = path;
      default = "${config.home.homeDirectory}/.scratch";
    };
    linkDirs = mkOption {
      type = listOf str;
      default = [ ];
    };
  };
  config.home = mkIf cfg.enable {
    file = (genAttrs cfg.linkDirs (path: {
      source = mkOutOfStoreSymlink "${cfg.path}/${path}";
    }));
    activation = {
      scratchDirMigration = config.lib.dag.entryBefore [ "checkLinkTargets" ] ''
        (
          $DRY_RUN_CMD cd ${escapeShellArg cfg.path}
          for d in ${escapeShellArgs cfg.linkDirs}; do
            if [[ ! -L "$HOME/$d" ]]; then
              if [[ -e "$d" ]]; then
                echo "ERROR: scratch dir already exists: $d" >&2
                exit 1
              fi
              $DRY_RUN_CMD mkdir -p "$(dirname "$d")"
              $DRY_RUN_CMD mv "$HOME/$d" "$d"
            fi
          done
        )
      '';
      scratchDirs = config.lib.dag.entryBetween [ "linkGeneration" ] [ "writeBoundary" ] ''
        (
          $DRY_RUN_CMD cd ${escapeShellArg cfg.path}
          $DRY_RUN_CMD mkdir -p ${escapeShellArgs cfg.linkDirs}
        )
      '';
    };
  };
}
