{ config, lib, ... }: with lib; let
  diskScsi = { config, ... }: {
    options = {
      driver = mkOption {
        type = types.enum [ "scsi-hd" "scsi-cd" "scsi-block" ];
        default = if config.iscsi.enable then "scsi-block" else "scsi-hd";
        description = "block is for scsi passthrough, hd is for block devices and scsi emulation";
      };
      slot = mkOption {
        type = types.int;
        default = 0;
      };
      lun = mkOption {
        type = types.int;
      };
      id = mkOption {
        type = types.int;
        default = 0;
      };
      channel = mkOption {
        type = types.int;
        default = 0;
      };
      bus = mkOption {
        type = types.str;
        default = "scsi0";
      };
      rotationRate = mkOption {
        type = types.int;
        default = 1;
      };
      iscsi = {
        enable = mkEnableOption "ISCSI" // {
          default = config.iscsi.initiatorName != null;
        };
        initiatorName = mkOption {
          type = with types; nullOr str;
          default = null;
        };
      };
    };
  };
  diskIde = { config, ... }: {
    options = {
      driver = mkOption {
        type = types.enum [ "ide-hd" "ide-cd" ];
        default = "ide-hd";
      };
      bus = mkOption {
        type = types.str;
        default = "ide0";
      };
      slot = mkOption {
        type = types.int;
      };
    };
  };
  diskModule = cfg: { config, name, ... }: {
    options = {
      enable = mkEnableOption "disk" // {
        default = true;
      };
      path = mkOption {
        type = types.path;
      };
      readonly = mkOption {
        type = types.bool;
        default = config.scsi.driver or null == "scsi-cd" || config.ide.driver or null == "ide-cd";
      };
      scsi = mkOption {
        type = with types; nullOr (submodule diskScsi);
        default = null;
      };
      ide = mkOption {
        type = with types; nullOr (submodule diskIde);
        default = null;
      };
      virtio.enable = mkEnableOption "virtio-blk";
      drive = mkOption {
        type = unmerged.type;
        default = { };
      };
      device = mkOption {
        type = unmerged.type;
        default = { };
      };
    };
    config = {
      drive = mkMerge [
        {
          settings = {
            readonly = mkIf config.readonly true;
            file = config.path;
            discard = "unmap";
            "if" = "none";
            format = "raw";
          };
        }
        (mkIf config.scsi.iscsi.enable or false {
          settings = {
            driver = "iscsi";
            initiator-name = config.scsi.iscsi.initiatorName;
          };
        })
        (mkIf (config.scsi != null) {
          settings = {
            aio = "native";
            "cache.direct" = true;
          };
        })
      ];
      device = mkMerge [
        {
          settings = {
            id = "${name}-dev";
            drive = cfg.drives.${name}.id;
          };
        }
        (mkIf (config.scsi != null) {
          settings = {
            inherit (config.scsi) channel lun driver;
            scsi-id = config.scsi.id;
            bus = "${config.scsi.bus}.${toString config.scsi.slot}";
            rotation_rate = mkIf (config.scsi.driver == "scsi-hd") (toString config.scsi.rotationRate);
          };
        })
        (mkIf (config.ide != null) {
          settings = {
            inherit (config.ide) driver;
            bus = "${config.ide.bus}.${toString config.ide.slot}";
          };
        })
        (mkIf config.virtio.enable {
          settings = {
            driver = "virtio-blk-pci";
            scsi = false;
          };
        })
      ];
    };
  };
in {
  options = {
    disks = mkOption {
      type = with types; attrsOf (submodule (diskModule config));
      default = { };
    };
  };
  config = let
    disks = filterAttrs (_: disk: disk.enable) config.disks;
  in {
    drives = mapAttrs (name: disk: unmerged.merge disk.drive) disks;
    devices = mapAttrs (name: disk: unmerged.merge disk.device) (filterAttrs (_: disk: !disk.virtio.enable) disks);
    pci.devices = mapAttrs (name: disk: {
      device = unmerged.merge disk.device;
    }) (filterAttrs (_: disk: disk.virtio.enable) disks);
  };
}
