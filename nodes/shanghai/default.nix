{ pkgs, config, lib, ... }: with lib; {
  imports = [
    ../../hw/x570am
    ../../hw/nvidia
    ../../cfg/personal
    ../../cfg/users/kat
    ../../cfg/gui
    ../../cfg/cross.nix
    ../../cfg/vfio
    ../../cfg/trusted.nix
    ./mradio.nix
    ./audio.nix
    ./network.nix
    ./fs.nix
    ./vfio
  ];

  config = {
    home-manager.users.arc = { ... }: {
      imports = [ ./home.nix ];
    };

    system.stateVersion = "22.11";

    services.ddclient.enable = true;
    services.ofono.enable = true;
    services.systemd2mqtt.enable = true;
    systemd.services.ofono.wantedBy = [ "multi-user.target" ];
    hardware.openrazer.enable = true;

    hardware.display = {
      enable = true;
      monitors = (import ./displays.nix { inherit lib; }).default config.hardware.display.monitors;
    };
    services.xserver = {
      displayManager = {
        startx.enable = mkForce false;
        lightdm = {
          # TODO: switch to lxdm?
          enable = !config.services.xserver.displayManager.startx.enable;
          # https://wiki.archlinux.org/title/LightDM#Long_pause_before_LightDM_shows_up_when_home_is_encrypted
          greeters.gtk.extraConfig = mkIf (config.fileSystems ? "/mnt/enc") ''
            hide-user-image=true
          '';
        };
        session = singleton {
          manage = "desktop";
          name = "xsession";
          start = ''
            ${pkgs.runtimeShell} ~/.xsession &
            waitPID=$!
          '';
        };
      };
    };
    services.systemd2mqtt.units = {
      "dpms-standby.service".settings.invert = true;
    };

    users = {
      chroot.users = [ "kat" ];
      users.kat.group = "kat";
      groups.kat = { };
    };

    boot = {
      extraModulePackages = [ config.boot.kernelPackages.v4l2loopback.out ];
      modprobe.modules = {
        v4l2loopback.options = {
          # https://github.com/umlaeute/v4l2loopback/blob/main/README.md
          devices = 8;
        };
      };
    };
    hardware.cpu.info = {
      modelName = "AMD Ryzen 9 5950X 16-Core Processor";
      cores = 16;
    };
  };
}
