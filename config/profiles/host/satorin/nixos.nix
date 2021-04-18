{ pkgs, config, lib, ... }: with lib; {
  options.home = {
    profiles.host.satorin = mkEnableOption "hostname: satorin";
  };

  config = mkIf config.home.profiles.host.satorin {
    home.profiles.trusted = true;
    home.profiles.gui = true;
    home.profiles.hw.xps13 = true;
    home.profiles.host.gensokyo = true;

    networking = {
      hostId = "451b608e";
      nftables.ruleset = mkAfter (builtins.readFile ./files/nftables.conf);
    };

    deploy.network.local.ipv4 = "10.1.1.64";
    services.openssh.ports = [ 22 64022 ];
    #networking.connman.extraFlags = ["-I" "eth0" "-I" "wlan0"]; # why did I have this there? these don't even exist?

    boot = {
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
    home.hw.xps13.wifi = "ax210";
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
    };
    swapDevices = [
      { device = "/dev/disk/by-partuuid/a1ec1791-770e-4541-9945-33fc64c4d2cf"; }
    ];
  };
}
