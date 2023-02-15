{ pkgs, options, nixosConfig, config, lib, ... }@args: with lib; let
  inherit (nixosConfig.services) xserver;
  cfg = config.services.idle;
  isHome = options ? home.homeDirectory;
  nixosConfig = if isHome then args.nixosConfig else config;
  waitForX = pkgs.writeShellScript "idle-wait-x" ''
    while ! ${getExe pkgs.xorg.xset} q > /dev/null; do
      ${pkgs.coreutils}/bin/sleep 1
    done
  '';
  service = rec {
    wantedBy = [ "display-manager.service" ];
    bindsTo = wantedBy;
    after = wantedBy;
    serviceConfig = {
      ExecStartPre = [
        # give login manager time to start up
        waitForX
      ];
      ExecStart = [
        ''${getExe cfg.xss-lock.package} ${toString cfg.xss-lock.arguments} -- ${escapeShellArgs cfg.xss-lock.command}''
      ];
      Environment = mkIf xserver.enable (
        optional (xserver.staticDisplay != null) "DISPLAY=:${toString xserver.staticDisplay}"
        ++ optional (xserver.authority != null) "XAUTHORITY=${xserver.authority}"
      );
    };
  };
  homeService = rec {
    Unit = {
      BindsTo = Install.WantedBy;
      After = Unit.BindsTo;
    };
    Service = {
      inherit (service.serviceConfig) ExecStart;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
in {
  options.services.idle = with types; {
    enable = mkEnableOption "idle service";
    xss-lock = {
      arguments = mkOption {
        type = listOf str;
        default = [];
      };
      command = mkOption {
        type = listOf str;
      };
      package = mkOption {
        type = package;
        default = pkgs.xss-lock;
        defaultText = "pkgs.xss-lock";
      };
    };
  };
  config = {
    services.idle = {
      xss-lock = {
        arguments = [
          "--ignore-sleep"
          (mkIf (isHome && xserver.displayManager.startx.enable)
            "--session=\${XDG_SESSION_ID}"
          )
        ];
      };
    };
    systemd = mkIf cfg.enable (if isHome then {
      user.services.idle = homeService;
    } else {
      services.idle = service;
      services.display-manager.unitConfig.Upholds = [ "idle.service" ];
    });
  };
}
