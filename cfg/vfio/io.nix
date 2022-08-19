{ lib, config, pkgs, ... }: with lib; let
  cfg = config.hardware.vfio;
  nixosConfig = config;
  systemdUnits =
    mapAttrsToList (_: dev: dev.systemd) cfg.devices;
  polkitPermissions = systemd: mkIf systemd.enable {
    ${systemd.polkit.user} = {
      systemd.units = [ systemd.id ];
    };
  };
  systemdService = systemd: {
    ${systemd.name} = unmerged.merge systemd.unit;
  };
  systemdModule = { config, ... }: {
    options = {
      enable = mkEnableOption "systemd service" // {
        default = true;
      };
      name = mkOption {
        type = types.str;
      };
      id = mkOption {
        type = types.str;
        default = config.name + ".service";
      };
      depends = mkOption {
        type = with types; listOf str;
        default = [ ];
      };
      wants = mkOption {
        type = with types; listOf str;
        default = [ ];
      };
      user = mkOption {
        type = with types; nullOr str;
        default = null;
      };
      polkit.user = mkOption {
        type = with types; nullOr str;
        default = config.user;
      };
      type = mkOption {
        type = types.str;
        default = "oneshot";
      };
      script = mkOption {
        type = types.lines;
        default = "";
      };
      unit = mkOption {
        type = unmerged.type;
      };
    };
    config = {
      unit = {
        inherit (config) enable;
        path = [ pkgs.coreutils ];
        after = mkIf (config.depends != [ ] || config.wants != [ ]) (config.depends ++ config.wants);
        requires = mkIf (config.depends != [ ]) config.depends;
        wants = mkIf (config.wants != [ ]) config.wants;
        script = mkIf (config.script != "") config.script;
        restartIfChanged = mkDefault false;
        serviceConfig = {
          User = mkIf (config.user != null) (mkDefault config.user);
          Type = mkDefault config.type;
          RemainAfterExit = mkIf (config.type == "oneshot") (mkDefault true);
        };
      };
    };
  };
  vfioDeviceModule = { config, name, ... }: {
    options = {
      enable = mkEnableOption "VFIO device";
      vendor = mkOption {
        type = types.strMatching "[0-9a-f]{4}";
      };
      product = mkOption {
        type = types.strMatching "[0-9a-f]{4}";
      };
      unbindVts = mkEnableOption "unbind-vts";
      host = mkOption {
        type = with types; nullOr str;
        default = null;
        example = "02:00.0";
      };
      systemd = mkOption {
        type = types.submodule systemdModule;
        default = { };
      };
    };
    config = {
      systemd = {
        name = "vfio-reserve-${name}";
        script = mkMerge (
          optional config.unbindVts "${nixosConfig.lib.arc-vfio.unbind-vts}/bin/unbind-vts"
          ++ singleton "${nixosConfig.lib.arc-vfio.reserve-pci}/bin/reserve-pci ${config.vendor}:${config.product}"
        );
        unit.serviceConfig = {
          RuntimeDirectory = config.systemd.name;
          ExecStop = "${nixosConfig.lib.arc-vfio.reserve-pci}/bin/reserve-pci STOP";
        };
      };
    };
  };
in {
  options.hardware.vfio = {
    devices = mkOption {
      type = with types; attrsOf (submodule vfioDeviceModule);
      default = { };
    };
  };
  config = {
    systemd.services = mkMerge (map systemdService systemdUnits);
    security.polkit.users = mkMerge (map polkitPermissions systemdUnits);
    boot.modprobe.modules = {
      vfio-pci = let
        vfio-pci-ids = mapAttrsToList (_: dev:
          "${dev.vendor}:${dev.product}"
        ) (filterAttrs (_: dev: dev.enable) cfg.devices);
      in mkIf (vfio-pci-ids != [ ]) {
        options.ids = concatStringsSep "," vfio-pci-ids;
      };
    };
  };
}
