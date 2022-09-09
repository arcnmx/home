{ config, lib, ... }: with lib; let
  cfg = config.ivshmem;
  ivshmemDeviceModule = machineConfig: { config, name, ... }: {
    options = {
      enable = mkEnableOption "IVSHMEM device" // {
        default = true;
      };
      mode = mkOption {
        type = types.enum [ "plain" "doorbell" ];
        default = "plain";
      };
      path = mkOption {
        type = types.path;
      };
      sizeMB = mkOption {
        type = types.int;
      };
      vectors = mkOption {
        type = types.int;
        default = 1;
      };
      count = mkOption {
        type = types.int;
      };
      share = mkOption {
        type = types.bool;
        default = true;
      };
      serverScript = mkOption {
        type = types.str;
      };
      object = mkOption {
        type = unmerged.type;
      };
      pciDevice = mkOption {
        type = unmerged.type;
      };
    };
    config = {
      serverScript = mkIf (config.type == "doorbell") ''
        if [[ ! -f ${config.pidfile} ]] || ! kill -s 0 $(cat ${config.pidfile}) 2> /dev/null; then
          ivshmem-server -p ${config.pidfile} -S ${config.path} -l ${toString config.sizeMB}M -n ${toString config.count}
        fi
      '';
      object = {
        inherit (config) enable;
        settings = if config.mode == "doorbell" then {
          backend = "socket";
          id = "${name}-socket";
          inherit (config) path;
        } else {
          typename = "memory-backend-file";
          id = "${name}-mem";
          inherit (config) share;
          mem-path = config.path;
          size = "${toString config.sizeMB}M";
        };
      };
      pciDevice = mkMerge [
        {
          settings.driver = "ivshmem-${config.mode}";
        }
        (mkIf (config.mode == "plain") {
          device.cli.dependsOn = [ machineConfig.objects.${name}.id ];
          settings.memdev = machineConfig.objects.${name}.id;
        })
        (mkIf (config.mode == "doorbell") {
          device.cli.dependsOn = [ machineConfig.chardevs.${name}.id ];
          settings = {
            chardev = machineConfig.chardevs.${name}.id;
            inherit (config) vectors;
          };
        })
      ];
    };
  };
in {
  options.ivshmem = {
    enable = mkEnableOption "IVSHMEM" // {
      default = cfg.devices != { };
    };
    devices = mkOption {
      type = with types; attrsOf (submodule (ivshmemDeviceModule config));
      default = { };
    };
  };
  config = mkIf cfg.enable {
    objects = mapAttrs (name: dev: unmerged.merge dev.object) (filterAttrs (_: dev: dev.mode == "plain") cfg.devices);
    chardevs = mapAttrs (name: dev: unmerged.merge dev.object) (filterAttrs (_: dev: dev.mode == "doorbell") cfg.devices);
    pci.devices = mapAttrs (name: dev: unmerged.merge dev.pciDevice) (filterAttrs (_: dev: dev.enable) cfg.devices);
  };
}
