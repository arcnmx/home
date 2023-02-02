{ lib, ... }: with lib; {
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

    fileSystems = let
      wdauto = [ "x-systemd.automount" "x-systemd.mount-timeout=2m" "x-systemd.idle-timeout=30m" "noauto" ];
    in {
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
            # https://wiki.archlinux.org/title/Dm-crypt/Specialties#Disable_workqueue_for_increased_solid_state_drive_(SSD)_performance
            "no-read-workqueue" "no-write-workqueue"
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
      "/mnt/efi" = {
        device = "/dev/disk/by-uuid/1016-9B5D";
        fsType = "vfat";
        options = ["rw" "strictatime" "lazytime" "errors=remount-ro"];
      };
      "/mnt/wdarchive" = {
        device = "/dev/disk/by-uuid/da37f8cd-9934-4d08-b0cf-a4d5ead43454";
        fsType = "ext4";
        options = wdauto;
      };
      "/mnt/wdworking" = {
        device = "/dev/disk/by-uuid/64629b8d-8eae-4a00-87b2-d3fe2763cf34";
        fsType = "ext4";
        options = wdauto;
      };
      "/mnt/wdmisc" = {
        device = "/dev/disk/by-uuid/d2c686b4-b7e1-4866-a8e9-efaa7964cbe5";
        fsType = "ext4";
        options = wdauto;
      };
      "/mnt/wdtemp" = {
        device = "/dev/disk/by-uuid/56ea5e87-7344-4eeb-bf1a-166f174c9904";
        fsType = "ext4";
        options = wdauto;
      };
    };
    swapDevices = [
      {
        # 16G adata
        device = "/dev/disk/by-partuuid/0ecca923-20db-c34b-807b-2be849bf2017";
        randomEncryption.enable = true;
      }
      {
        # 32G Plextor
        device = "/dev/disk/by-partuuid/38b62f92-2fa2-4ee3-9e20-77a77a8e2b31";
        randomEncryption.enable = true;
      }
      {
        # 32G SN770
        device = "/dev/disk/by-partuuid/0002fc58-b222-4fd3-80a4-a442137352ee";
        randomEncryption.enable = true;
      }
    ];
  };
}
