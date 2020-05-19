{ pkgs, lib, config, ... }: with lib; {
  options.network = {
    nixos = {
      extraModules = mkOption {
        type = types.listOf types.path;
        default = [ ]; # TODO: config/modules/nixos and channels/arc/modules/nixos
      };
      modulesPath = mkOption {
        type = types.path;
        default = toString (config.channels.paths.nixpkgs + "/nixos/modules");
      };
    };
    nodes = let
      nixosModule = { config, ... }: {
        config = {
          nixpkgs = {
            system = mkDefault pkgs.system;
            pkgs = mkDefault pkgs;
          };

          _module.args.pkgs = mkDefault (import pkgs.path {
            inherit (config.nixpkgs) config overlays localSystem crossSystem;
          });
        };
      };
      nixosType = let
        baseModules = import (config.network.nixos.modulesPath + "/module-list.nix");
      in types.submoduleWith {
        modules = baseModules
          ++ singleton nixosModule
          ++ config.network.nixos.extraModules;

        specialArgs = {
          inherit baseModules;
          inherit (config.network.nixos) modulesPath;
          inherit (config.network) nodes;
          meta = config;
        };
      };
    in mkOption {
      type = types.attrsOf nixosType;
      default = { };
    };
  };
}
