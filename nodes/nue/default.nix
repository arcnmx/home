{ config, lib, ... }: with lib; {
  imports = [
    ../../hw/um5302
    ../../cfg/personal
    ../../cfg/trusted.nix
    ../../cfg/gui
    ../../cfg/secure-boot
    ./fs.nix
    ./network.nix
  ];

  config = {
    #deploy.personal.enable = mkForce false;
    home-manager.users.arc = { ... }: {
      imports = [ ./home.nix ];
    };

    system.stateVersion = "22.11";

    hardware.cpu.info.cores = 8;

    hardware.display = {
      enable = true;
      monitors = (import ./displays.nix { inherit lib; }).default config.hardware.display.monitors;
      oled = singleton config.hardware.display.monitors.internal.output;
      dpi = config.hardware.display.monitors.internal.dpi.out.dpi;
      fontScale = 1.35;
    };
  };
}
