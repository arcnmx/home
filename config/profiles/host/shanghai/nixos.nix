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
    hardware.openrazer = {
      enable = true;
      devicesOffOnScreensaver = false;
      mouseBatteryNotifier = false;
      #syncEffectsEnabled = false;
    };
    hardware.pulseaudio.extraConfig = let
      usb = "usb-C-Media_Electronics_Inc._USB_Audio_Device-00";
    in ''
      #load-module module-mmkbd-evdev

      load-module module-alsa-sink sink_name=onboard device=surround40:CARD=Generic,DEV=0 format=s32 rate=48000 channels=4 channel_map=front-left,front-right,rear-left,rear-right tsched=1 fixed_latency_range=0 fragment_size=1024 fragments=16
      load-module module-alsa-source source_name=mic device=front:CARD=Generic,DEV=0 format=s32 rate=96000 tsched=1

      load-module module-remap-sink sink_name=speakers master=onboard channels=2 channel_map=left,front-right master_channel_map=rear-left,rear-right remix=no sink_properties=device.description=Speakers
      load-module module-remap-sink sink_name=headphones master=onboard channels=2 channel_map=left,front-right master_channel_map=front-left,front-right remix=no sink_properties=device.description=Headphones
      load-module module-virtual-surround-sink sink_name=vsurround sink_master=headphones hrir=${./files/hrir-kemar.wav} sink_properties="device.description='Headphones VSurround'"

      load-module module-echo-cancel source_master=mic sink_master=headphones source_name=mic_headphones sink_name=mic_headphones_sink use_volume_sharing=1 use_master_format=1 channels=1 aec_method=webrtc aec_args="analog_gain_control=0 digital_gain_control=1 noise_suppression=1 high_pass_filter=1 extended_filter=1 experimental_agc=1 intelligibility_enhancer=0 agc_start_volume=150"
      load-module module-echo-cancel source_master=mic sink_master=speakers source_name=mic_speakers sink_name=mic_speakers_sink use_volume_sharing=1 use_master_format=1 channels=1 aec_method=webrtc aec_args="analog_gain_control=0 digital_gain_control=1 noise_suppression=1 high_pass_filter=0 extended_filter=1 experimental_agc=1 agc_start_volume=200"

      set-default-source mic
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
