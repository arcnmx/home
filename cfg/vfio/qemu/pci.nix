{ config, lib, pkgs, inputs, ... }: with lib; let
  cfg = config.pci;
  machineConfig = config;
  pciDeviceModule = { config, name, ... }: {
    options = {
      settings = mkOption {
        type = with types; attrsOf unspecified;
        default = { };
      };
      device = mkOption {
        type = unmerged.type;
      };
    };
    config = {
      settings = mapAttrs (_: mkOptionDefault) {
        inherit (cfg) bus;
      };
      device = {
        cli.dependsOn = [ machineConfig.devices.${name}.settings.bus ];
        settings = mapAttrs (_: mkDefault) config.settings;
      };
    };
  };
in {
  options.pci = {
    bus = mkOption {
      type = types.str;
      default = if config.machine.settings.type or null == "q35" then "pcie.0" else "pci.0";
    };
    devices = mkOption {
      type = with types; attrsOf (submodule pciDeviceModule);
      default = { };
    };
  };
  config.devices = mapAttrs (name: dev: unmerged.merge dev.device) cfg.devices;
}
