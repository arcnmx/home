{ config, pkgs, lib, ... }: with lib; {
  options = {
    home.profiles.hw.x570am = mkEnableOption "GIGABYTE X570 Aorus Master";
  };

  config = mkIf config.home.profiles.hw.x570am {
    home.profiles.hw.ryzen = true;

    boot = {
      kernelModules = [ "it87" ];
      extraModulePackages = with config.boot.kernelPackages; [ it87 ];
      initrd.availableKernelModules = [
        "nvme" "sd_mod" "xhci_pci" "ahci" "usbhid"
      ];
      modprobe.modules = {
        snd_hda_intel.options = {
          model = "dual-codecs";
        };
        it87.options = {
          force_id = "0x8628";
        };
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
    environment.etc = {
      "sensors3.conf".text = ''
        chip "it8628-isa-0a40"
          label temp1 "System 1"
          label temp2 "Chipset"
          label temp3 "CPU Socket"
          label temp4 "PCIEX16"
          label temp5 "VRM MOS"
          label temp6 "VSOC MOS"
          label in0 "CPU Vcore"
          label in1 "+3.3V"
          label in2 "+12V"
          label in3 "+5V"
          label in4 "CPU Vcore SOC"
          label in5 "CPU Vddp"
          label in6 "DRAM A/B"
      '';
    };
    systemd.network = {
      networks.eno1 = {
        inherit (config.systemd.network.links.eth) matchConfig;
        bridge = ["br"];
      };
      networks.eno2 = {
        inherit (config.systemd.network.links.eth25) matchConfig;
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
