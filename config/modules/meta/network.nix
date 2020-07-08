{ pkgs, lib, config, ... }: with lib; {
  options.network = {
    nixos = {
      extraModules = mkOption {
        type = types.listOf types.unspecified;
        default = [ ];
      };
      specialArgs = mkOption {
        type = types.attrsOf types.unspecified;
        default = { };
      };
      modulesPath = mkOption {
        type = types.path;
        default = toString (config.channels.paths.nixpkgs + "/nixos/modules");
      };
    };
    yggdrasil = mkOption {
      type = types.attrs;
      default = { };
    };
    wan = mkOption {
      type = types.attrs;
      default = { };
    };
    nodes = let
      nixosModule = { config, meta, modulesPath, lib, ... }: with lib; {
        imports = [ ../nixos ];
        config = {
          nixpkgs = {
            system = mkDefault pkgs.system;
            pkgs = mkDefault pkgs;
            inherit (meta.channels.config.nixpkgs) config overlays; # TODO: mkDefault?
          };
          nix = {
            inherit (meta.channels) nixPath;
          };
          home = {
            extraModules = meta.home.extraModules;
            specialArgs = meta.home.specialArgs;
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
        } // config.network.nixos.specialArgs;
      };
    in mkOption {
      type = types.attrsOf nixosType;
      default = { };
    };
  };
  config.network = {
    nixos = {
      extraModules = [
        "${toString config.channels.paths.home-manager}/nixos"
        "${toString config.channels.paths.arc}/modules/nixos"
      ];
      specialArgs = {
        inherit (config.network) nodes;
        meta = config;
      };
    };
    yggdrasil = mapAttrs (name: node: {
      address = node.services.yggdrasil.address;
    }) config.network.nodes;
    wan = mapAttrs (name: node: {
      address = "${node.networking.hostName}.${node.networking.domain}";
    }) config.network.nodes;
  };
}
