{ pkgs, nixosConfig, options, config, lib, ... }@args: with lib; let
  inherit (nixosConfig.services) xserver;
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
  start = pkgs.writeShellScript "dpms-start.sh" ''
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

    POINTER_IDS=$(${pkgs.coreutils}/bin/cat $RUNTIME_DIRECTORY/pointers)

    ${getExe pkgs.xorg.xset} dpms force on

    for pointer in $POINTER_IDS; do
      ${getExe pkgs.xorg.xinput} --enable $pointer ||
        echo "WARN: failed to enable xinput id=$pointer" >&2
    done
  '';
  control = pkgs.writeShellScript "dpms-standby-control" ''
    set -eu
    ${nixosConfig.systemd.package}/bin/systemctl ${optionalString isHome "--user"} "$1" dpms-standby.service
  '';
  isHome = options ? home.homeDirectory;
  nixosConfig = if isHome then args.nixosConfig else config;
  homeSkel = isHome && nixosConfig.services.dpms-standby.enable;
  Environment = [
    "DPMS_INTERVAL=${toString cfg.pollInterval}"
    "DPMS_INTERVAL_MS=${toString (floor (cfg.pollInterval * 1000))}"
  ];
  service = rec {
    requisite = mkIf (xserver.enable && !xserver.displayManager.startx.enable) [ "display-manager.service" ];
    bindsTo = requisite;
    after = requisite;
    serviceConfig = {
      Type = "forking";
      RuntimeDirectory = "dpms-standby";
      ExecStart = [ "${start}" ];
      ExecStop = [ "${stop}" ];
      User = mkIf (cfg.user != null) cfg.user;
      Environment = mkMerge [
        Environment
        (mkIf xserver.enable (
          optional (xserver.staticDisplay != null) "DISPLAY=:${toString xserver.staticDisplay}"
          ++ optional (xserver.authority != null) "XAUTHORITY=${xserver.authority}"
        ))
      ];
    };
  };
  homeService = {
    Unit = rec {
      Requisite = [ "graphical-session.target" ];
      BindsTo = Requisite;
    };
    Service = {
      inherit Environment;
      inherit (service.serviceConfig)
        Type RuntimeDirectory
        ExecStart ExecStop
      ;
    };
  };
in {
  options.services.dpms-standby = with types; {
    enable = mkEnableOption "DPMS standby" // {
      default = if homeSkel then true else (nixosConfig.hardware.display.dpms.enable && (if isHome
        then config.xsession.enable
        else xserver.enable && !xserver.displayManager.startx.enable
      ));
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
      default = if homeSkel
        then nixosConfig.services.dpms-standby.control
        else control;
    };
  } // optionalAttrs (!isHome) {
    user = mkOption {
      type = nullOr str;
      default = null;
    };
  };

  config = mkMerge [ {
    services.idle.xss-lock.command = mkIf cfg.enable (mkAfter [
      "${cfg.control}" "start"
    ]);
  } (mkIf (cfg.enable && !homeSkel) {
    systemd = if isHome then {
      user.services.dpms-standby = homeService;
    } else {
      services.dpms-standby = service;
    };
    services.idle.enable = mkDefault true;
  }) ];
}
