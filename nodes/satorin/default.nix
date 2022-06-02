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

    system.stateVersion = "21.11";

    systemd.watchdog.enable = false;
    home.hw.xps13.wifi = "ax210";
  };
}
