{ pkgs, config, lib, ... }: with lib; {
  imports = [
    ../../hw/x570am
    ../../hw/nvidia
    ../../cfg/personal
    ../../cfg/gui
    ../../cfg/cross.nix
    ../../cfg/vfio
    ../../cfg/trusted.nix
    ./audio.nix
    ./network.nix
    ./fs.nix
    ./vfio.nix
  ];

  config = {
    home-manager.users.arc = { ... }: {
      imports = [ ./home.nix ];
    };

    system.stateVersion = "22.05";

    services.ddclient.enable = true;
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
    hardware.cpu.info = {
      modelName = "AMD Ryzen 9 5950X 16-Core Processor";
      cores = 16;
    };
  };
}
