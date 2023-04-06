{ pkgs, lib, inputs, config, ... }: with lib; {
  options.home = {
    username = mkOption {
      type = types.str;
      default = builtins.getEnv "USER";
    };
    homeDirectory = mkOption {
      type = types.path;
      default = builtins.getEnv "HOME";
    };
    extraModules = mkOption {
      type = types.listOf types.unspecified;
      default = [ ];
    };
    specialArgs = mkOption {
      type = types.attrsOf types.unspecified;
      default = { };
    };
    profiles = let
      modulesPath = inputs.home-manager + "/modules";
      hmlib = import (modulesPath + "/lib/stdlib-extended.nix") pkgs.lib;
      homeModules = import (modulesPath + "/modules.nix") {
        inherit pkgs;
        lib = hmlib;
        #check = ?;
      };
      homeType = types.submoduleWith {
        modules = homeModules ++ config.home.extraModules;

        specialArgs = {
          inherit modulesPath;
          lib = hmlib;
        } // config.home.specialArgs;
      };
    in mkOption {
      type = types.attrsOf homeType;
      default = { };
    };
  };
  config.home = {
    specialArgs = {
      inherit (config.network) nodes;
      meta = config;
    };
    extraModules = [
      ../home
      "${toString inputs.arc}/modules/home"
      "${toString inputs.tf}/modules/home"
      ({
        config = {
          home.username = mkDefault config.home.username;
          home.homeDirectory = mkDefault config.home.homeDirectory;
        };
      })
    ];
  };
}
