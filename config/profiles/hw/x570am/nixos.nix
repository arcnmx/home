{ config, pkgs, lib, ... }: with lib; {
  options = {
    home.profiles.hw.x570am = mkEnableOption "GIGABYTE X570 Aorus Master";
  };

  config = mkIf config.home.profiles.hw.x570am {
    home.profiles.hw.ryzen = true;

    boot = {
      initrd.availableKernelModules = [
        "nvme" "sd_mod" "xhci_pci" "ahci" "usbhid"
      ];
      modprobe.modules.snd_hda_intel.options = {
        model = "dual-codecs";
      };
    };
    hardware.bluetooth = {
      enable = true;
      package = pkgs.bluezFull;
    };
    hardware.pulseaudio = {
      package = pkgs.pulseaudioFull;
      bluetooth.enable = true;
      x11bell.enable = mkForce false; # buggy audio drivers make this a bad idea :<
    };
    environment.systemPackages = with pkgs; [
      wirelesstools
      bluez
    ];
    systemd.network = {
      networks.eno1 = {
        inherit (config.systemd.network.links.eth) matchConfig;
        bridge = ["br"];
      };
      netdevs.br = {
        netdevConfig = {
          Name = "br";
          Kind = "bridge";
          inherit (config.systemd.network.links.eth.matchConfig) MACAddress;
        };
      };
      links = {
        wlan = {
          matchConfig = {
            MACAddress = "a4:b1:c1:d9:14:df";
          };
          linkConfig = {
            Name = "wlan";
          };
        };
        eth = {
          matchConfig = {
            MACAddress = "18:c0:4d:08:87:bd";
            Type = "ether";
          };
          linkConfig = {
            Name = "eth";
          };
        };
        eth25 = {
          matchConfig = {
            MACAddress = "18:c0:4d:08:87:bc";
            Type = "ether";
          };
          linkConfig = {
            Name = "eth25";
          };
        };
      };
    };
  };
}
