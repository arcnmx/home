{ pkgs, lib, config, ... }: with lib; {
  options.home = {
    profiles = let
      modulesPath = config.channels.paths.home-manager + "/modules";
      hmlib = import (modulesPath + "/lib/stdlib-extended.nix") pkgs.lib;
      homeModules = import (modulesPath + "/modules.nix") {
        inherit pkgs;
        lib = hmlib;
        #check = ?;
      };
      homeType = types.submoduleWith {
        modules = homeModules;

        specialArgs = {
          inherit modulesPath;
          meta = config;
          lib = hmlib;
          inherit (config.network) nodes;
        };
      };
    in mkOption {
      type = types.attrsOf homeType;
      default = { };
    };
  };
}
