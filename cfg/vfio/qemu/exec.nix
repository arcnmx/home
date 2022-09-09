{ nixosConfig, config, lib, pkgs, ... }: with lib; let
  cfg = config.exec;
  cliModule = { config, ... }: {
    options = {
      condition = mkOption {
        type = with types; nullOr str;
        default = null;
      };
    };
  };
in {
  options = {
    exec = {
      pidfile = mkOption {
        type = with types; nullOr path;
        default = config.state.runtimePath + "/pid";
      };
      preExec = mkOption {
        type = types.lines;
        default = "";
      };
      postExec = mkOption {
        type = types.lines;
        default = "";
      };
      scriptText = mkOption {
        type = types.lines;
        default = "";
      };
      package = mkOption {
        type = types.package;
      };
    };
    cli = mkOption {
      type = with types; attrsOf (submodule cliModule);
    };
  };
  config = {
    args.pidfile = mkIf (cfg.pidfile != null) cfg.pidfile;
    exec = {
      preExec = mkMerge [
        (mkIf (cfg.pidfile != null) (mkBefore ''
          if [[ -f "${toString cfg.pidfile}" ]] && kill -0 $(cat "${toString cfg.pidfile}") 2> /dev/null; then
            echo "instance already running" >&2
            exit 1
          fi
        ''))
        ''printf %d -150 > /proc/self/oom_score_adj''
      ];
      scriptText = let
        escapeArg = line:
          if hasInfix " " line
          then ''"${line}"''
          else line;
        cli = filterAttrs (_: cli: cli.enable) config.cli;
        cliSorted' = sort (lhs: rhs: lhs.order < rhs.order) (attrValues cli);
        cliSorted = partition (cli: cli.condition == null) cliSorted';
        cliLine = cli: "-${cli.name.name}" +
          optionalString (cli.value != null) " ${escapeArg cli.value}";
      in mkMerge ([
        (mkOrder 999 ''
          QEMU_FLAGS=(
          ${concatMapStringsSep "\n" cliLine cliSorted.right}
          )
        '')
        (mkOrder 2000 ''
          exec ${nixosConfig.hardware.vfio.qemu.package}/bin/qemu-system-x86_64 "''${QEMU_FLAGS[@]}"
        '')
      ] ++ map (cli: mkOrder 1250 ''
        if ${cli.condition}; then
          QEMU_FLAGS+=(${cliLine cli})
        fi
      '') cliSorted.wrong);
      package = pkgs.writeShellScriptBin "vm-${config.name}" cfg.scriptText;
    };
  };
}
