{ lib, ... }: with lib; {
  imports = [
    ../../hw/xps13
    ../../cfg/personal
    ../../cfg/gui
    ../../cfg/trusted.nix
    ./fs.nix
    ./network.nix
    ./audio.nix
  ];

  config = {
    home-manager.users.arc = { ... }: {
      imports = [ ./home.nix ];
    };

    system.stateVersion = "22.11";

    systemd.watchdog.enable = false;
    hardware.cpu.info.cores = 2;

    boot.kernel.bleedingEdge = true;

    hardware.display = {
      monitors.internal.dpi.target = 96 * 2;
      fontScale = 0.95;
    };
  };
}
