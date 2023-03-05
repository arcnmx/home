{ nixosConfig, config, trusted, lib, ... }: with lib; let
  inherit (nixosConfig.hardware.vfio) disks windowsGames;
  sector4k = {
    logical_block_size = 4096;
    physical_block_size = 4096;
  };
in {
  imports = [
    ./common.nix ./audio.nix ./scream.nix ./virtio.nix
    ./windows-i440fx.nix
    ./dmi-gigabyte.nix
    ./vfio.nix
  ] ++ trusted.import.nixos "vfio/machines/hourai";
  options.lookingGlass.vertical = mkOption {
    type = types.bool;
    default = true;
  };
  config = {
    enable = mkDefault true;
    name = "hourai";
    virtio.enable = true;
    memory.sizeMB = 12 * 1024;
    smp = {
      settings = {
        threads = 1;
        cores = nixosConfig.hardware.cpu.info.cores * 2 / 3;
      };
    };
    systemd.depends = mapAttrsToList (name: _:
      mkIf config.disks."games-${name}-arc".enable "vfio-mapdisk-windows-games-${name}-arc.service"
    ) windowsGames;
    disks = {
      windows = {
        scsi.lun = 0;
        path = "/dev/disk/by-partlabel/windows-vm-adata";
      };
      games-plextor = {
        scsi.lun = 1;
        from.mapped = "windows-games-plextor";
      };
      intel = {
        scsi = {
          driver = "scsi-block";
          lun = 2;
        };
        path = "/dev/disk/by-id/ata-INTEL_SSDSC2BP480G4_BTJR442300QQ480BGN";
      };
      game-storage = {
        scsi.lun = 3;
        from.mapped = "game-storage";
      };
      games-adata2 = {
        scsi.lun = 4;
        from.mapped = "windows-games-adata2";
      };
      games-adata = {
        scsi.lun = 5;
        from.mapped = "windows-games-adata";
      };
      games-adata3 = {
        scsi.lun = 6;
        from.mapped = "windows-games-adata3";
      };
      games-sn850x = {
        scsi.lun = 7;
        from.mapped = "windows-games-sn850x";
        device.settings = sector4k;
      };
      games-sabrent = {
        scsi.lun = 8;
        from.mapped = "windows-games-sabrent";
        device.settings = sector4k;
      };
    } // listToAttrs (concatLists (mapAttrsToList (name: data: [
      (nameValuePair "games-${name}" (data // {
        from.cow = "windows-games-${name}";
      }))
      (nameValuePair "games-${name}-arc" {
        enable = !config.disks."games-${name}".enable;
        scsi = {
          inherit (config.disks."games-${name}") lun;
        };
        path = "/dev/disk/windows-games-${name}-arc";
      })
    ]) windowsGames));
    usb.host.devices = {
      svse5.enable = true;
      gmmk.enable = false;
      hori.enable = true;
      xpad.enable = true;
      switch-pro.enable = true;
      nagatrinity.enable = false;
      shift.enable = false;
      oculus-sensor.enable = true;
      oculus-audio.enable = true;
      oculus-hub2.enable = false;
      oculus-hub3.enable = false;
      oculus-headset.enable = true;
    };
    spice.usb.enable = true;
    lookingGlass = {
      enable = config.vfio.gpu == "rtx3080";
      sizeMB = if config.lookingGlass.vertical then 256 else 128;
    };
    vfio.devices = {
      hostusb = {
        inherit (nixosConfig.hardware.vfio.devices.hostusb) enable;
      };
    };
    netdevs = {
      hostnet0.settings = {
        type = "bridge";
        br = "br";
        helper = "${nixosConfig.security.wrapperDir}/${nixosConfig.security.wrappers.qemu-bridge-helper.program}";
      };
      smbnet0.settings = {
        type = "user";
        restrict = "yes";
        net = "10.1.2.0/24";
        host = "10.1.2.1";
        smb = config.state.path + "/smb";
        smbserver = "10.1.2.2";
      };
      natnet0.settings = {
        type = "user";
        net = "10.1.3.0/24";
        host = "10.1.3.1";
      };
    };
  };
}
