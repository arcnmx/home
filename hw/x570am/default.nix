{ config, pkgs, lib, ... }: with lib; {
  key = "GIGABYTE X570 Aorus Master";

  imports = [
    ../ryzen
  ];

  config = {
    home-manager.users.arc = { ... }: {
      imports = [ ./home.nix ];
    };

    boot = {
      kernel.arch = mkIf (versionAtLeast config.boot.kernelPackages.stdenv.cc.version "11") "znver3";
      kernelParams = [ "acpi_enforce_resources=lax" ];
      kernelModules = [ "it87" ];
      extraModulePackages = with config.boot.kernelPackages; [ it87 ];
      initrd.availableKernelModules = [
        "nvme" "sd_mod" "xhci_pci" "ahci" "usbhid"
      ];
      modprobe.modules = {
        it87.options = {
          force_id = "0x8628";
        };
      };
    };
    hardware.bluetooth = {
      enable = true;
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
    networking.wireless.mainInterface.arcCard = "ax200";
    systemd.network = let inherit (config.systemd.network) links; in {
      networks.eno1 = {
        inherit (links."10-eth") matchConfig;
        bridge = ["br"];
      };
      networks.eno2 = {
        inherit (links."10-eth25") matchConfig;
        bridge = ["br"];
      };
      netdevs.br = {
        netdevConfig = {
          Name = "br";
          Kind = "bridge";
          inherit (links."10-eth".matchConfig) MACAddress;
        };
      };
      links = {
        "10-eth" = {
          matchConfig = {
            MACAddress = "18:c0:4d:08:87:bd";
            Type = "ether";
          };
          linkConfig = {
            Name = "eth";
            NamePolicy = "";
          };
        };
        "10-eth25" = {
          matchConfig = {
            MACAddress = "18:c0:4d:08:87:bc";
            Type = "ether";
          };
          linkConfig = {
            Name = "eth25";
            NamePolicy = "";
          };
        };
      };
    };
  };
}
