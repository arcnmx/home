{ pkgs, config, lib, ... }: with lib; let
  inherit (config.services) xserver;
  cfg = config.services.dpms-standby;
  checkIdle = if cfg.checkIdle then ''
    if [[ $(${getExe pkgs.xprintidle}) -lt $DPMS_INTERVAL_MS ]]; then
      echo "unidle detected" >&2
      break
    fi
  '' else "true";
  monitor = pkgs.writeShellScript "dpms-monitor.sh" ''
    set -eu

    while ${pkgs.coreutils}/bin/sleep $DPMS_INTERVAL && ${getExe pkgs.xorg.xset} q | ${getExe pkgs.gnugrep} -q 'Monitor is Off'; do
      ${checkIdle}
    done
  '';
  service = pkgs.writeShellScript "dpms-start.sh" ''
    set -eu

    POINTER_IDS=$(${getExe pkgs.xorg.xinput} --list --short |
      ${getExe pkgs.gnugrep} -F -v 'XTEST' |
      ${getExe pkgs.gnugrep} 'slave *pointer' |
      ${getExe pkgs.gnugrep} -o 'id=[0-9]*' |
      ${pkgs.coreutils}/bin/cut -d= -f2
    )
    echo "$POINTER_IDS" > $RUNTIME_DIRECTORY/pointers

    for pointer in $POINTER_IDS; do
      ${getExe pkgs.xorg.xinput} --disable $pointer ||
        echo "WARN: failed to disable xinput id=$pointer" >&2
    done

    ${getExe pkgs.xorg.xset} dpms force off

    ${pkgs.coreutils}/bin/sleep $DPMS_INTERVAL

    ${monitor} &
  '';
  stop = pkgs.writeShellScript "dpms-stop.sh" ''
    set -eu

    POINTER_IDS=$(cat $RUNTIME_DIRECTORY/pointers)

    ${getExe pkgs.xorg.xset} dpms force on

    for pointer in $POINTER_IDS; do
      ${getExe pkgs.xorg.xinput} --enable $pointer ||
        echo "WARN: failed to enable xinput id=$pointer" >&2
    done
  '';
in {
  options.services.dpms-standby = with types; {
    enable = mkEnableOption "DPMS standby";
    display = mkOption {
      type = nullOr int;
      default = 0;
    };
    user = mkOption {
      type = nullOr str;
      default = null;
    };
    xauthority = mkOption {
      type = nullOr path;
      default = null;
    };
    pollInterval = mkOption {
      type = float;
      default = 2.5;
    };
    checkIdle = mkOption {
      type = bool;
      default = false;
    };
    control = mkOption {
      type = package;
      default = pkgs.writeShellScript "dpms-standby-control" ''
        set -eu
        ${config.systemd.package}/bin/systemctl "$1" dpms-standby.service
      '';
    };
  };

  config.services.dpms-standby = {
    xauthority = mkMerge [
      (mkIf xserver.displayManager.lightdm.enable (mkDefault
        "/var/run/lightdm/root/:${toString cfg.display}"
      ))
    ];
    display = mkIf (xserver.display != null) xserver.display;
  };
  config.systemd.services.dpms-standby = mkIf cfg.enable rec {
    requisite = mkIf (!xserver.displayManager.startx.enable) [ "display-manager.service" ];
    bindsTo = requisite;
    serviceConfig = {
      Type = "forking";
      RuntimeDirectory = "dpms-standby";
      ExecStart = "${service}";
      ExecStop = "${stop}";
      User = mkIf (cfg.user != null) cfg.user;
      Environment = [
        "DPMS_INTERVAL=${toString cfg.pollInterval}"
        "DPMS_INTERVAL_MS=${toString (floor (cfg.pollInterval * 1000))}"
      ] ++ optional (cfg.display != null) "DISPLAY=:${toString cfg.display}"
      ++ optional (cfg.xauthority != null) "XAUTHORITY=${cfg.xauthority}";
    };
  };
}
