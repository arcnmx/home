{ ... }: {
  config = {
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
      supportedFilesystems = ["btrfs" "xfs"];
      tmpOnTmpfsSize = "64G";
    };
    services.journald.extraConfig = ''
      SystemMaxUse=3G
    '';

    fileSystems = {
      "/mnt/old" = {
        device = "/dev/disk/by-uuid/4a260bff-eac5-40c9-8c40-00f0557b5923";
        fsType = "btrfs";
        options = [ "x-systemd.automount" "noauto" "rw" "relatime" "user_subvol_rm_allowed" "compress=zstd" "ssd" "space_cache" "subvol=/" "nofail" ];
      };
      "/nix" = {
        device = "/dev/disk/by-uuid/a82e1a40-e0e5-4461-a29d-42caf5a502b6";
        fsType = "xfs";
        options = ["rw" "relatime"]; # discard
      };
      "/boot" = {
        device = "/mnt/efi/EFI/nixos";
        fsType = "none";
        options = ["bind"];
      };
      "/mnt/bigdata" = {
        device = "/dev/disk/by-uuid/2354ffd4-67b6-49e6-90f1-22cc2a116ff1";
        fsType = "btrfs";
        options = [ "x-systemd.automount" "noauto" "rw" "strictatime" "lazytime" "user_subvol_rm_allowed" "compress=zstd" "space_cache" "autodefrag" "subvol=/bigdata" "nofail" ];
      };
      "/" = {
        device = "/dev/disk/by-uuid/76b9ccba-7d5f-4ceb-b0aa-476c63ebb60f";
        fsType = "btrfs";
        options = [ "rw" "relatime" "user_subvol_rm_allowed" "compress=zstd" "ssd" "space_cache" "subvol=/" ];
      };
      "/mnt/enc" = {
        device = "/dev/mapper/enc";
        fsType = "xfs";
        options = [ "x-systemd.automount" "noauto" ];
        encrypted = {
          enable = false;
          label = "enc";
          blkDev = "/dev/disk/by-uuid/cc8e597e-228d-49b6-af65-a47ced8dd57a"; # PARTLABEL=shanghai-enc
        };
        crypttab = {
          enable = true;
          options = [
            "luks" "discard" "noauto" "nofail"
          ];
        };
      };
      "/home/arc" = {
        device = "/mnt/enc/home/arc";
        fsType = "none";
        options = [ "bind" "x-systemd.automount" "noauto" "nofail" ];
        depends = [ "/mnt/enc" ];
      };
      "/mnt/data" = {
        device = "/dev/disk/by-uuid/9407fd0a-683b-4839-908d-e65cb9b5fec5";
        fsType = "btrfs";
        options = ["rw" "strictatime" "lazytime" "user_subvol_rm_allowed" "compress=zstd" "ssd" "space_cache" "subvol=/" "nofail"];
      };
      "/mnt/efi-old" = {
        device = "/dev/disk/by-uuid/D460-0EF6";
        fsType = "vfat";
        options = [ "x-systemd.automount" "noauto" "rw" "strictatime" "lazytime" "errors=remount-ro" "nofail" ];
      };
      "/mnt/efi" = {
        device = "/dev/disk/by-uuid/1016-9B5D";
        fsType = "vfat";
        options = ["rw" "strictatime" "lazytime" "errors=remount-ro"];
      };
      "/mnt/wdarchive" = {
        device = "/dev/disk/by-uuid/da37f8cd-9934-4d08-b0cf-a4d5ead43454";
        fsType = "ext4";
        options = [ "x-systemd.automount" "noauto" ];
      };
      "/mnt/wdworking" = {
        device = "/dev/disk/by-uuid/64629b8d-8eae-4a00-87b2-d3fe2763cf34";
        fsType = "ext4";
        options = [ "x-systemd.automount" "noauto" ];
      };
      "/mnt/wdmisc" = {
        device = "/dev/disk/by-uuid/d2c686b4-b7e1-4866-a8e9-efaa7964cbe5";
        fsType = "ext4";
        options = [ "x-systemd.automount" "noauto" ];
      };
    };
    swapDevices = [
      {
        # 72G Plextor
        device = "/dev/disk/by-partuuid/38b62f92-2fa2-4ee3-9e20-77a77a8e2b31";
        randomEncryption.enable = true;
      }
      {
        # 16G BPX
        device = "/dev/disk/by-partuuid/8a7fdfac-14bc-431e-9907-1069ec937e88";
        randomEncryption.enable = true;
      }
      {
        # 16G sabrent
        device = "/dev/disk/by-partuuid/0ecca923-20db-c34b-807b-2be849bf2017";
        randomEncryption.enable = true;
      }
    ];
  };
}
