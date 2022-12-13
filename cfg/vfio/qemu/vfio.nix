{ nixosConfig, config, lib, ... }: with lib; let
  cfg = config.vfio;
  vfiocfg = nixosConfig.hardware.vfio;
  vfioDeviceModule = { config, name, ... }: {
    options = {
      enable = mkEnableOption "VFIO device" // {
        default = true;
      };
      name = mkOption {
        type = types.str;
        default = name;
      };
      rombar = mkOption {
        type = with types; nullOr int;
        default = 1;
      };
      romfile = mkOption {
        type = with types; nullOr path;
        default = null;
      };
    };
  };
in {
  options.vfio = {
    enable = mkEnableOption "VFIO" // {
      default = config.vfio.devices != { };
    };
    devices = mkOption {
      type = with types; attrsOf (submodule vfioDeviceModule);
      default = { };
    };
  };
  config = let
    enabledDevices = filterAttrs (_: vfio: vfio.enable) cfg.devices;
  in mkIf cfg.enable {
    systemd.depends = mapAttrsToList (_: vfio: vfiocfg.devices.${vfio.name}.vfio.id) enabledDevices;
    pci.devices = mapAttrs (name: vfio: {
      settings = mapAttrs (_: mkOptionDefault) {
        driver = "vfio-pci";
        inherit (vfio) rombar romfile;
        inherit (vfiocfg.devices.${vfio.name}) host;
      };
    }) enabledDevices;
  };
}
