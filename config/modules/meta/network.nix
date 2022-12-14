{ pkgs, lib, config, inputs, trusted, ... }: with lib; {
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
        options.nixpkgs = {
          path = mkOption {
            type = types.path;
            default = pkgs.path;
          };
          crossOverlays = mkOption {
            type = types.listOf types.unspecified;
            default = [ ];
          };
        };
        config = {
          nixpkgs = {
            system = mkDefault pkgs.system;
            pkgs = let
              pkgsReval = import config.nixpkgs.path {
                inherit (config.nixpkgs) config localSystem crossSystem crossOverlays;
                inherit (meta.channels.config.nixpkgs) overlays;
              };
              untouched =
                config.nixpkgs.config == pkgs.config
                && config.nixpkgs.localSystem.system == pkgs.buildPlatform.system
                && config.nixpkgs.crossSystem == null
                && config.nixpkgs.path == pkgs.path;
            in mkDefault (if untouched then pkgs else pkgsReval);
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
            inherit pkgs;
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
          inherit baseModules trusted inputs;
          inherit (config.network.nixos) modulesPath;
          inherit (config.network.nixos.specialArgs) nodes meta;
        }; #// config.network.nixos.specialArgs;
      };
    in mkOption {
      type = types.attrsOf nixosType;
      default = { };
    };
  };
  config.network = {
    nixos = {
      extraModules = let
        tf = import (config.channels.paths.tf + "/modules");
        arc = import (config.channels.paths.arc + "/modules");
        hm = config.channels.paths.home-manager + "/nixos";
      in [
        (toString hm)
        arc.nixos
        tf.nixos tf.run
      ];
      specialArgs = {
        inherit (config.network) nodes;
        meta = config;
      };
    };
  };
}
