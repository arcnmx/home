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
      nixosModule = { name, config, meta, modulesPath, lib, ... }: with lib; {
        imports = [ ../nixos ];
        config = {
          nixpkgs = {
            system = mkDefault pkgs.system;
            pkgs = let
              pkgsReval = import pkgs.path {
                inherit (config.nixpkgs) config localSystem crossSystem;
                inherit (meta.channels.config.nixpkgs) overlays;
              };
            in mkDefault (if config.nixpkgs.config == pkgs.config && config.nixpkgs.localSystem.system == pkgs.targetPlatform.system then pkgs else pkgsReval);
            inherit (meta.channels.config.nixpkgs) config; # TODO: mkDefault?
          };
          nix = {
            inherit (meta.channels) nixPath;
          };
          home = {
            extraModules = meta.home.extraModules;
            specialArgs = meta.home.specialArgs;
          };
          runners = {
            lazy = {
              inherit (meta.runners.lazy) file args;
              attrPrefix = "network.nodes.${name}.runners.run.";
            };
          };
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
        "${toString config.channels.paths.tf}/modules/nixos"
        "${toString config.channels.paths.tf}/modules/run.nix"
      ];
      specialArgs = {
        inherit (config.network) nodes;
        meta = config;
      };
    };
  };
}
