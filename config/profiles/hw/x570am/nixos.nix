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
        matchConfig.Name = "enp7s0";
        bridge = ["br"];
      };
      netdevs.br = {
        netdevConfig = {
          Name = "br";
          Kind = "bridge";
          MACAddress = "18:c0:4d:08:87:bd";
        };
      };
    };
  };
}
