{ config, lib, ... }: with lib; let
  homeModule = { ... }: {
    config = {
      home = {
        nixosConfig = config;
        hostName = config.networking.hostName;
      };

      _module.args = config.home.specialArgs;
    };
  };
in {
  options.home = {
    hostName = mkOption {
      type = types.str;
      default = config.networking.hostName;
    };
    extraModules = mkOption {
      type = types.listOf types.unspecified;
      default = [ ];
    };
    specialArgs = mkOption {
      type = types.attrsOf types.unspecified;
      default = { };
    };
  };
  config.home = {
    extraModules = [ homeModule ];
    specialArgs = {
      nixos = config;
    };
  };
}
