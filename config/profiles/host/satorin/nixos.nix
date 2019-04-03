{ pkgs, config, lib, ... }: with lib; {
  options.home = {
    profiles.host.satorin = mkEnableOption "hostname: satorin";
  };

  config = mkIf config.home.profiles.host.satorin {
    home.profiles.trusted = true;
    home.profiles.gui = true;
    home.profiles.hw.xps13 = true;

    networking.hostId = "451b608e";

    systemd.network.links.wlan = {
      matchConfig = {
        MACAddress = "00:15:00:ec:c6:51";
      };
      linkConfig = {
        Name = "wlan";
      };
    };
    services.openssh.ports = [64022];
    #networking.connman.extraFlags = ["-I" "eth0" "-I" "wlan0"]; # why did I have this there? these don't even exist?

    boot = {
      kernelPackages = lib.mkForce pkgs.linuxPackages_4_19; # ZFS rc broken on 5.0
      kernelParams = ["zfs.zfs_arc_max=${toString (512*1024*1024)}"];
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
      supportedFilesystems = ["zfs"];
      zfs = {
        enableUnstable = true;
        requestEncryptionCredentials = true;
      };
    };
    services.zfs = {
      autoScrub = {
        enable = true;
        interval = "*-*-01 05:00:00"; # 1st of the month at 5am
      };
    };

    fileSystems = {
      "/" = {
        device = "satorin/root/nixos";
        fsType = "zfs";
      };
      "/home" = {
        device = "satorin/root/home";
        fsType = "zfs";
      };
      "/boot" = {
        device = "/mnt/efi/EFI/nixos";
        fsType = "none";
        options = ["bind"];
      };
      "/mnt/efi" = {
        device = "/dev/disk/by-uuid/17CA-FD91";
        fsType = "vfat";
        options = ["rw" "strictatime" "lazytime" "errors=remount-ro"];
      };
      "/mnt/old" = {
        device = "/dev/disk/by-uuid/5cb5485c-9417-441c-a96e-6369c0f9530c";
        fsType = "btrfs";
        options = ["ro"];
        noCheck = true;
      };
    };
    swapDevices = [
      { device = "/dev/disk/by-partuuid/a1ec1791-770e-4541-9945-33fc64c4d2cf"; }
    ];
  };
}
