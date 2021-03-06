{ lib, config, ... }: with lib; {
  imports = (import ./profiles/modules.nix { }).metaImports;
  config = {
    deploy = {
      dataDir = ../deploy;
      archive = {
        repos.workingDir = config.deploy.dataDir + "/gitarchive/working";
        borg.repos = {
          ${config.deploy.idTag} = {
            repoDir = config.deploy.dataDir + "/data";
            keyFile = config.deploy.dataDir + "/data.key";
            passphraseShellCommand = "bitw get tokens/borg-home -f passphrase";
          };
          repos = {
            repoDir = config.deploy.dataDir + "/gitarchive/data";
            keyFile = config.deploy.dataDir + "/gitarchive.key";
            passphraseShellCommand = "bitw get tokens/borg-home-git -f passphrase";
          };
        };
      };
    };
    runners = {
      lazy = {
        file = ../default.nix;
        args = [ "--show-trace" ];
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
