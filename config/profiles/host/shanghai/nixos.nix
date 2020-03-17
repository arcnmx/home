{ config, pkgs, lib, ... }: with lib; {
  options = {
    home.profiles.host.shanghai = mkEnableOption "hostname: shanghai";
  };

  config = mkIf config.home.profiles.host.shanghai {
    home.profiles.trusted = true;
    home.profiles.host.gensokyo = true;
    home.profiles.personal = true;
    home.profiles.gui = true;
    home.profiles.vfio = true;
    home.profiles.hw.nvidia = true;
    home.profiles.hw.x370gpc = true;

    networking = {
      hostId = "a1184652";
      useDHCP = false;
      useNetworkd = true;
    };
    systemd.network.networks.br = {
      matchConfig.Name = "br";
      gateway = [ "10.1.1.1" ];
      address = [ "10.1.1.32/24" ];
    };

    home.nixbld.enable = true;
    services.ddclient.enable = true;
    services.mosh = {
      enable = true;
      ports = {
        from = 32600;
        to = 32700;
      };
    };
    services.openssh.ports = [ 22 32022 ];
    hardware.pulseaudio.extraConfig = lib.mkAfter ''
      #load-module module-mmkbd-evdev

      load-module module-virtual-surround-sink sink_name=vsurround sink_master=alsa_output.usb-C-Media_Electronics_Inc._USB_Audio_Device-00.analog-stereo hrir=/etc/pulse/hrir_kemar/hrir-kemar.wav

      set-default-sink alsa_output.pci-0000_20_00.3.analog-stereo
      #set-default-source alsa_input.pci-0000_20_00.3.analog-stereo # broken alsa driver

      #set-default-sink alsa_output.usb-C-Media_Electronics_Inc._USB_Audio_Device-00.analog-stereo
      set-default-source alsa_input.usb-C-Media_Electronics_Inc._USB_Audio_Device-00.analog-mono
    '';

    services.udev.extraRules = ''
      SUBSYSTEM=="module", ACTION=="add", KERNEL=="acpi_cpufreq", RUN+="${pkgs.runtimeShell} -c 'for x in /sys/devices/system/cpu/cpufreq/*/scaling_governor; do echo performance > $$x; done'"

      # my VM disks
      SUBSYSTEM=="block", ACTION=="add", ATTRS{model}=="INTEL SSDSC2BP48", ATTRS{wwid}=="*BTJR442300QQ480BGN*", OWNER="arc"
      SUBSYSTEM=="block", ACTION=="add", ATTR{partition}=="6", ATTR{size}=="134217728", ATTRS{wwid}=="eui.002303563000ad1b", OWNER="arc"
    '';
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
      deviceSection = ''
        BusID "PCI:40:0:0" # NOTE: this is decimal, be careful! IDs are typically shown in hex
        Option "Monitor-DVI-D-0" "Monitor[0]" # LG
        Option "Monitor-HDMI-0" "Monitor[1]" # BenQ (DVI -> HDMI)
        Option "Monitor-DP-1" "Monitor[2]" # Acer (DP -> HDMI)
      '';
      screenSection = ''
        Option "MetaModes" "${let
          #offset = 1440 / 3;
          offset = 0;
          h = 2160 + offset;
        in concatStringsSep ", " [
          "HDMI-0: 2560x1440 +0+${toString (h - 1440)}"
          "DVI-D-0: 3840x2160 +2560+0"
          "DP-1: 1920x1080 +${toString (2560 + 3840)}+${toString (h - 1080)}"
        ]}"
      '';
      monitorSection = ''
        Option "Primary" "true"
        Option "DPMS" "true"
        Option "DPI" "96 x 96"
      '';
      extraConfig = ''
        Section "Monitor"
          Identifier "Monitor[1]"
          Option "DPMS" "true"
          Option "DPI" "96 x 96"
        EndSection
        Section "Monitor"
          Identifier "Monitor[2]"
          Option "DPMS" "true"
          Option "DPI" "96 x 96"
        EndSection
      '';
    };

    boot = mkMerge [ {
      loader = {
        generationsDir = {
          copyKernels = true;
        };
        systemd-boot.enable = true;
        efi = {
          canTouchEfiVariables = false;
          efiSysMountPoint = "/mnt/efi";
        };
      };
      supportedFilesystems = ["btrfs"];
    } (let
      vfio-pci-ids = [
        # "10de:1c81" "10de:0fb9" # GTX 1050
        "10de:1e07" "10de:10f7" "10de:1ad6" "10de:1ad7" # RTX 2080 Ti
      ];
    in mkIf config.home.profiles.vfio {
      # TODO: extraModprobeConfig does not seem to be placed in initrd, see: https://github.com/NixOS/nixpkgs/issues/25456
      #extraModprobeConfig = mkIf config.home.profiles.vfio ''
      #  options vfio-pci ids=${concatStringsSep "," vfio-pci-ids}
      #'';
      kernelParams = [
        "vfio-pci.ids=${concatStringsSep "," vfio-pci-ids}"
      ];
    }) ];

    fileSystems = {
      "/" = {
        device = "/dev/disk/by-uuid/4a260bff-eac5-40c9-8c40-00f0557b5923";
        fsType = "btrfs";
        options = ["rw" "relatime" "user_subvol_rm_allowed" "compress=zstd" "ssd" "space_cache" "subvol=/"];
      };
      "/boot" = {
        device = "/mnt/efi/EFI/nixos";
        fsType = "none";
        options = ["bind"];
      };
      "/mnt/bigdata" = {
        device = "/dev/disk/by-uuid/2354ffd4-67b6-49e6-90f1-22cc2a116ff1";
        fsType = "btrfs";
        options = ["rw" "strictatime" "lazytime" "user_subvol_rm_allowed" "compress=zstd" "space_cache" "autodefrag" "subvol=/bigdata" "nofail"];
      };
      "/mnt/data" = {
        device = "/dev/disk/by-uuid/9407fd0a-683b-4839-908d-e65cb9b5fec5";
        fsType = "btrfs";
        options = ["rw" "strictatime" "lazytime" "user_subvol_rm_allowed" "compress=zstd" "ssd" "space_cache" "subvol=/" "nofail"];
      };
      "/mnt/efi" = {
        device = "/dev/disk/by-uuid/D460-0EF6";
        fsType = "vfat";
        options = ["rw" "strictatime" "lazytime" "errors=remount-ro"];
      };
    };
    swapDevices = [
      { device = "/dev/disk/by-uuid/4faab83b-164e-444c-b1b6-4a26e7f7e6bf"; }
    ];
  };
}
