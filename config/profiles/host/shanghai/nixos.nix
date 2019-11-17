{ config, pkgs, lib, ... }: with lib; {
  options = {
    home.profiles.host.shanghai = mkEnableOption "hostname: shanghai";
  };

  config = mkIf config.home.profiles.host.shanghai {
    home.profiles.trusted = true;
    home.profiles.host.gensokyo = true;
    home.profiles.personal = true;
    home.profiles.gui = true;

    networking.hostId = "a1184652";

    home.nixbld.enable = true;
    services.mosh.portRange = "32600:32700";
    hardware.pulseaudio.extraConfig = lib.mkAfter ''
      #load-module module-mmkbd-evdev

      load-module module-virtual-surround-sink sink_name=vsurround sink_master=alsa_output.usb-C-Media_Electronics_Inc._USB_Audio_Device-00.analog-stereo hrir=/etc/pulse/hrir_kemar/hrir-kemar.wav

      set-default-sink alsa_output.pci-0000_20_00.3.analog-stereo
      #set-default-source alsa_input.pci-0000_20_00.3.analog-stereo # broken alsa driver

      #set-default-sink alsa_output.usb-C-Media_Electronics_Inc._USB_Audio_Device-00.analog-stereo
      set-default-source alsa_input.usb-C-Media_Electronics_Inc._USB_Audio_Device-00.analog-mono
    '';

    services.udev.extraRules = ''
      SUBSYSTEM=="module", ACTION=="add", KERNEL=="acpi_cpufreq", RUN+="/bin/sh -c 'for x in /sys/devices/system/cpu/cpufreq/*/scaling_governor; do echo performance > $$x; done'"
    '';

    boot = {
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
    };

    fileSystems = {
      "/" = {
        device = "/dev/disk/by-uuid/0ffac5c5-dbcf-42bf-a79c-4c5fd8557e2d";
        fsType = "btrfs";
        options = ["rw" "strictatime" "lazytime" "user_subvol_rm_allowed" "compress=zstd" "ssd" "space_cache" "subvol=/root"];
      };
      "/home" = {
        device = "/dev/disk/by-uuid/0ffac5c5-dbcf-42bf-a79c-4c5fd8557e2d";
        fsType = "btrfs";
        options = ["rw" "strictatime" "lazytime" "subvol=/home"];
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
      "/mnt/root" = {
        device = "/dev/disk/by-uuid/0ffac5c5-dbcf-42bf-a79c-4c5fd8557e2d";
        fsType = "btrfs";
        options = ["rw" "strictatime" "lazytime" "subvol=/" "nofail"];
      };
    };
    swapDevices = [
      { device = "/dev/disk/by-uuid/4faab83b-164e-444c-b1b6-4a26e7f7e6bf"; }
    ];
  };
}
