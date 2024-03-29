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
          efiSysMountPoint = "/mnt/esp2";
        };
      };
      initrd.luks.devices = {
        nuefs = {
          preLVM = false;
          bypassWorkqueues = true;
          allowDiscards = true;
        };
      };
      supportedFilesystems = [ "xfs" ];
      tmp.cleanOnBoot = true;
    };

    fileSystems = {
      "/" = {
        device = "/dev/mapper/nuefs";
        fsType = "xfs";
        encrypted = {
          enable = true;
          label = "nuefs";
          blkDev = "/dev/nuelvm/nuefs-enc";
        };
      };
      "/boot" = {
        device = "/mnt/esp2/EFI/nixos";
        fsType = "none";
        options = [ "bind" "nofail" ];
      };
      "/mnt/esp2" = {
        device = "/dev/disk/by-uuid/40D7-01ED";
        fsType = "vfat";
      };
    };
    swapDevices = [
      {
        device = "/dev/disk/by-partuuid/dd4619f2-60d8-451c-8930-90075159ac4c"; # PARTLABEL=swap
        randomEncryption.enable = true;
      }
    ];
  };
}
