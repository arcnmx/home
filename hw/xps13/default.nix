{ config, pkgs, lib, ... }: with lib; let
  cfg = config.home.hw.xps13;
in {
  key = "Dell XPS 13 (9343)";
  imports = [
    ../intel
    ../../cfg/laptop
  ];

  config = {
    home-manager.users.arc = { ... }: {
      imports = [ ./home.nix ];
    };

    boot = {
      kernel = {
        arch = "broadwell";
      };
      initrd.availableKernelModules = [
        "xhci_pci" "ehci_pci" "ahci" "sd_mod" "rtsx_pci_sdmmc"
      ];
    };

    hardware = {
      cpu = {
        info = {
          modelName = "Intel(R) Core(TM) i5-5200U CPU @ 2.20GHz";
        };
      };
      display = {
        enable = true;
        monitors = {
          internal = {
            output = "eDP1";
            xserver.sectionName = "Monitor[0]";
            primary = true;
            width = 1920;
            height = 1080;
            size = {
              diagonal = 13.3;
              width = 292;
              height = 165;
            };
          };
        };
        dpi = config.hardware.display.monitors.internal.dpi.out.dpi;
      };
    };

    services.xserver = {
      xrandrHeads = [{
        output = "eDP1";
        primary = true;
        monitorConfig = ''
          DisplaySize ${toString (292 * config.hardware.display.dpiScale)} ${toString (165 * config.hardware.display.dpiScale)} # millimeters
        '';
      }];

      synaptics = {
        palmDetect = true; # seems to work on ps/2 but not i2c
        palmMinWidth = 8;
        palmMinZ = 100;
      };
    };

    sound.extraConfig = ''
      defaults.ctl.!card PCH
      defaults.pcm.!card PCH
    '';
  };
}
