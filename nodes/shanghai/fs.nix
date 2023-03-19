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
      tmp.tmpfsSize = "64G";
    };
    services.journald.extraConfig = ''
      SystemMaxUse=3G
    '';
    nix.build.enable = false;

    fileSystems = let
      wdauto = [
        "x-systemd.automount" "x-systemd.mount-timeout=2m" "x-systemd.idle-timeout=30m"
        "noauto"
      ];
      btrfsopts = [ "compress=zstd" "ssd" ];
    in {
      "/nix" = {
        device = "/dev/disk/by-uuid/6f27e800-797a-4b1f-b0be-5c9cea8a29e9";
        fsType = "xfs";
      };
      "/boot" = {
        device = "/mnt/efi/EFI/nixos";
        fsType = "none";
        options = [ "bind" "nofail" ];
      };
      "/" = {
        device = "/dev/disk/by-uuid/8b5033f4-2ef4-4abb-b181-4ec45cd523fe";
        fsType = "btrfs";
        options = btrfsopts ++ [ "subvol=/" ];
      };
      "/mnt/enc" = { config, ... }: (config: { inherit config; }) {
        device = "/dev/mapper/${config.encrypted.label}";
        fsType = "xfs";
        options = [
          "x-systemd.automount" "noauto"
        ];
        encrypted = {
          enable = false;
          label = "enc-sn850x";
          blkDev = "/dev/disk/by-uuid/2275bc45-55c9-46ff-ad64-8fe5331e89e1"; # PARTLABEL=shanghai-enc-sn850x
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
      "/mnt/scratch" = { config, ... }: (config: { inherit config; }) {
        device = "/dev/disk/by-uuid/c86d8291-b8df-450d-bbef-c199dec0da8b"; # PARTLABEL=scratch-adata
        fsType = "btrfs";
        options = btrfsopts ++ [
          "subvol=/"
          "nofail"
        ];
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
        options = btrfsopts ++ [
          "space_cache" "subvol=/"
          "nofail"
        ];
      };
      "/mnt/efi" = {
        device = "/dev/disk/by-uuid/8584-BEFF"; # PARTLABEL=efi-sn850x
        fsType = "vfat";
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
        # 64G adata
        device = "/dev/disk/by-partuuid/3b3a71f5-3865-4c8c-9567-4d440a23feab";
        randomEncryption.enable = true;
      }
      {
        # 32G Plextor
        device = "/dev/disk/by-partuuid/38b62f92-2fa2-4ee3-9e20-77a77a8e2b31";
        randomEncryption.enable = true;
      }
    ];

    services.target = let
      plugin = "block"; # "pscsi" passthrough just caused a kernel panic so use block instead
    in {
      enable = true;
      storageObjects = {
        hgst = {
          inherit plugin;
          dev = "/dev/disk/by-id/ata-HGST_HDN724040ALE640_PK2334PEK42A2T";
        };
        seagate0 = {
          inherit plugin;
          dev = "/dev/disk/by-id/ata-ST4000DM000-1F2168_Z304RM7G";
        };
      };
      targets.default.portGroups = {
        big = {
          tag = 1;
          parameters = {
            DataDigest = "None";
          };
          portal."[::]" = { };
          lun = {
            hgst.index = 0;
            seagate0.index = 1;
          };
          node.tewi.lun = {
            hgst = { };
            seagate0 = { };
          };
        };
      };
    };
  };
}
