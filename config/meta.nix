{ lib, config, ... }: with lib; {
  imports = (import ./profiles/modules.nix { }).metaImports;
  config = {
    deploy = {
      dataDir = ../deploy;
    };
    home.profiles = {
      base = {
        imports = [
          ./home.nix
        ];
        home.profiles.base = mkDefault true;
      };

      personal = {
        imports = [
          ./home.nix
        ];
        home.profiles = {
          base = mkDefault true;
          personal = true;
        };
      };

      desktop = {
        imports = [
          ./home.nix
        ];
        home.profiles = {
          base = mkDefault true;
          personal = true;
          gui = true;
        };
      };

      laptop = {
        imports = [
          ./home.nix
        ];
        home.profiles = {
          base = mkDefault true;
          personal = true;
          gui = true;
          laptop = true;
        };
      };
    } // mapAttrs (host: _: {
      imports = [
        ./home.nix
      ];
      home = {
        profiles.base = mkDefault true;
        hostName = host;
      };
    }) (builtins.readDir ./profiles/host);
    /*home.profiles-applied = mapAttrs (_: configuration: import <home-manager/modules> {
      inherit configuration pkgs lib;
      #check = ??;
    }) config.home.profiles;*/
  };
}
