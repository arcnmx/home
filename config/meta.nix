{ lib, config, ... }: with lib; let
  trustedPath = ./profiles/trusted/meta.nix;
  hasTrusted = builtins.pathExists trustedPath;
in {
  imports = [
    ./profiles/host/gensokyo/meta.nix
    ./profiles/host/aya/meta.nix
    ./profiles/host/cirno/meta.nix
    ./profiles/host/mystia/meta.nix
    ./profiles/host/satorin/meta.nix
    ./profiles/host/shanghai/meta.nix
  ] ++ optional hasTrusted trustedPath;
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
  };
}
