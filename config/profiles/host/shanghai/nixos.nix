{ tf, config, pkgs, lib, ... }: with lib; {
  imports = [
    ./audio.nix
  ];

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
    home.profiles.hw.x570am = true;
    home.profiles.hw.cross = true;

    networking = {
      hostId = "a1184652";
      useDHCP = false;
      useNetworkd = true;
      nftables.ruleset = mkAfter (builtins.readFile ./files/nftables.conf);
    };
    deploy.network.local.ipv4 = "10.1.1.32";
    systemd.network.networks.br = {
      matchConfig.Name = "br";
      gateway = [ "10.1.1.1" ];
      address = [ "${config.deploy.network.local.ipv4}/24" ];
    };
    deploy.tf = {
      dns.records = mkIf (config.home.profileSettings.gensokyo.zone != null) {
        hourai = {
          inherit (tf.dns.records.local_a) zone;
          domain = "hourai";
          a.address = "10.1.1.36";
        };
      };
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
    services.ofono.enable = true;
    systemd.services.ofono.wantedBy = [ "multi-user.target" ];
    services.openssh.ports = [ 22 32022 ];
    hardware.openrazer.enable = true;

    services.udev.extraRules = ''
      # my VM disks
      SUBSYSTEM=="block", ACTION=="add", ATTRS{model}=="INTEL SSDSC2BP48", ATTRS{wwid}=="naa.55cd2e404b6f84e5", OWNER="arc"
      SUBSYSTEM=="block", ACTION=="add", ATTR{partition}=="4", ATTR{size}=="125829120", ATTRS{wwid}=="eui.6479a741e0203d76", OWNER="arc"
      SUBSYSTEM=="block", ACTION=="add", ATTR{partition}=="6", ATTR{size}=="134217728", ATTRS{wwid}=="eui.002303563000ad1b", OWNER="arc"
    '';
    hardware.display = {
      enable = true;
      monitors = (import ./displays.nix { inherit lib; }).default config.hardware.display.monitors;
    };
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
      deviceSection = mkMerge [
        # NOTE: this is decimal, be careful! IDs are typically shown in hex
        #''BusID "PCI:39:0:0"'' # primary GPU
        #''BusID "PCI:40:0:0"'' # secondary GPU
        ''BusID "PCI:05:0:0"'' # tertiary (chipset slot) GPU
      ];
    };

    boot = {
      extraModulePackages = [ config.boot.kernelPackages.v4l2loopback.out ];
      modprobe.modules = {
        vfio-pci = let
          vfio-pci-ids = [
            # "10de:1c81" "10de:0fb9" # 1050
            # "10de:1f82" "10de:10fa" # 1660
            "10de:2206" "10de:1aef" # 3080
          ];
        in mkIf (config.home.profiles.vfio && vfio-pci-ids != [ ]) {
          options.ids = concatStringsSep "," vfio-pci-ids;
        };
        v4l2loopback.options = {
          # https://github.com/umlaeute/v4l2loopback/blob/main/README.md
          devices = 8;
        };
      };
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
