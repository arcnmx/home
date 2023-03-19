{ lib, ... }: with lib; {
  config = {
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
    nixpkgs.overlays = singleton (self: super: {
      # enable zfsUnstable on unsupported kernel versions
      linuxPackagesOverlays = super.linuxPackagesOverlays or [ ]
      ++ singleton self.kernelPatches.overlays.zfsVersionOverride;
    });
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
        options = [ "bind" "nofail" ];
      };
      "/mnt/efi" = {
        device = "/dev/disk/by-uuid/17CA-FD91";
        fsType = "vfat";
      };
    };
    swapDevices = [
      { device = "/dev/disk/by-partuuid/a1ec1791-770e-4541-9945-33fc64c4d2cf"; }
    ];
  };
}
