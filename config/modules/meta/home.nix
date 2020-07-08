{ pkgs, lib, config, ... }: with lib; {
  options.home = {
    extraModules = mkOption {
      type = types.listOf types.unspecified;
      default = [ ];
    };
    specialArgs = mkOption {
      type = types.attrsOf types.unspecified;
      default = { };
    };
    profiles = let
      modulesPath = config.channels.paths.home-manager + "/modules";
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
      "${toString config.channels.paths.arc}/modules/home"
      ({
        # TODO: this better
        disabledModules = [
          (/. + "${toString config.channels.paths.home-manager}/modules/services/mpd.nix")
          (/. + "${toString config.channels.paths.home-manager}/modules/programs/git.nix")
          (/. + "${toString config.channels.paths.home-manager}/modules/programs/vim.nix")
          (/. + "${toString config.channels.paths.home-manager}/modules/programs/firefox.nix")
        ];
      })
    ];
  };
}
