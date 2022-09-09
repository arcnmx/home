{ config, lib, ... }: with lib; let
  machineConfig = config;
  cfg = config.hotplug;
  toValue = value:
    if value == true then "on"
    else if value == false then "off"
    else toString value;
  usbDeviceModule = { config, name, ... }: {
    options = {
      hotplug = mkEnableOption "hotplug" // {
        default = !config.enable;
      };
    };
  };
  hotplugDeviceModule = { config, name, ... }: {
    options = {
      enable = mkEnableOption "hotplug device" // {
        default = true;
      };
      default = mkOption {
        type = types.bool;
        default = false;
      };
      name = mkOption {
        type = types.str;
        default = name;
      };
      id = mkOption {
        type = types.str;
        default = name;
      };
      out = {
        monitorLine = mkOption {
          type = types.str;
        };
        addDeviceArgs = mkOption {
          type = with types; listOf str;
        };
        cli = mkOption {
          type = types.unspecified;
        };
        device = mkOption {
          type = types.unspecified;
        };
      };
    };
    config = {
      out = {
        monitorLine = ''device_add ${config.out.cli.value}'';
        cli = machineConfig.cli.${config.id};
        device = machineConfig.devices.${config.id};
        addDeviceArgs = mkMerge [
          (mkBefore [
            "--no-clobber"
            "--id" config.id
          ])
          (mkOrder 750 [ config.out.device.settings.driver ])
          (mapAttrsToList
            (key: value: "${key}=${toValue value}")
            (removeAttrs config.out.device.settings [ "id" "driver" ])
          )
        ];
      };
    };
  };
in {
  options.hotplug = {
    enable = mkEnableOption "hotplug devices" // {
      default = cfg.devices != { };
    };
    devices = mkOption {
      type = with types; attrsOf (submodule hotplugDeviceModule);
      default = { };
    };
  };
  options.usb.host.devices = mkOption {
    type = with types; attrsOf (submodule usbDeviceModule);
  };
  config = let
    usbDevices = filterAttrs (_: dev: dev.hotplug) config.usb.host.devices;
  in {
    hotplug.devices = mapAttrs (_: dev: {
      inherit (dev) name;
      default = mkDefault dev.enable;
    }) usbDevices;
  };
}
