{ nixosConfig, config, lib, ... }: with lib; let
  hostDevices = nixosConfig.hardware.vfio.usb.devices;
  cfg = config.usb;
  usbDeviceModule = { config, name, ... }: {
    options = {
      enable = mkOption {
        type = types.bool;
        default = true;
      };
      name = mkOption {
        type = types.str;
        default = name;
      };
      bus = mkOption {
        type = with types; nullOr str;
        default = cfg.bus;
      };
      vendor = mkOption {
        type = types.strMatching "[0-9a-f]{4}";
        default = hostDevices.${config.name}.vendor;
      };
      product = mkOption {
        type = types.nullOr (types.strMatching "[0-9a-f]{4}");
        default = hostDevices.${config.name}.product;
      };
      device = mkOption {
        type = unmerged.type;
      };
    };
    config = {
      device = {
        inherit (config) enable;
        cli.dependsOn = mkIf (config.bus != null) [ config.bus ];
        settings = mapAttrs (_: mkDefault) {
          driver = "usb-host";
          vendorid = "0x${config.vendor}";
        } // {
          productid = mkIf (config.product != null) (mkDefault "0x${config.product}");
        };
      };
    };
  };
in {
  options.usb = {
    enable = mkEnableOption "USB forwarding" // {
      default = cfg.host.devices != { };
    };
    bus = mkOption {
      type = with types; nullOr str;
      default = null;
    };
    host.devices = mkOption {
      type = with types; attrsOf (submodule usbDeviceModule);
      default = { };
    };
  };
  config = mkIf cfg.enable {
    devices = mapAttrs (name: dev: unmerged.merge dev.device) cfg.host.devices;
  };
}
