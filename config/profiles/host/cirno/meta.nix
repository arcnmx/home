{ lib, ... }: with lib; {
  config = {
    deploy.targets.cirno = {
      nodeNames = singleton "cirno";
    };
    network.nodes.cirno = { meta, ... }: {
      imports = let
        tf = import (meta.channels.paths.tf + "/modules");
      in [
        ../../../nixos.nix
        tf.nixos.oracle
        tf.nixos.ubuntu-linux # lustrate host image
      ];

      networking = {
        hostName = "cirno";
      };
    };
  };
}
