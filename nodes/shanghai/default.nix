{ pkgs, config, lib, ... }: with lib; {
  imports = [
    ../../hw/x570am
    ../../hw/nvidia
    ../../cfg/personal
    ../../cfg/gui
    ../../cfg/cross.nix
    ../../cfg/vfio
    ../../cfg/trusted.nix
    ../../cfg/ddclient
    ./audio.nix
    ./network.nix
    ./fs.nix
    ./vfio.nix
  ];

  config = {
    home-manager.users.arc = { ... }: {
      imports = [ ./home.nix ];
    };

    services.ofono.enable = true;
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
          enable = true;
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

    boot = {
      extraModulePackages = [ config.boot.kernelPackages.v4l2loopback.out ];
      modprobe.modules = {
        v4l2loopback.options = {
          # https://github.com/umlaeute/v4l2loopback/blob/main/README.md
          devices = 8;
        };
      };
    };
  };
}
