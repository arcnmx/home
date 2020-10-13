{ lib, config, ... }: with lib; {
  imports = (import ./profiles/modules.nix { }).metaImports;
  config = {
    deploy = {
      dataDir = ../deploy;
      archive.borg = {
        repoDir = config.deploy.dataDir + "/data";
        keyFile = config.deploy.dataDir + "/data.key";
        passphraseShellCommand = "bitw get tokens/borg-home -f passphrase";
      };
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
  };
}
