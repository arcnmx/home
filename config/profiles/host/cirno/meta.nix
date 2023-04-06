{ lib, inputs, ... }: with lib; {
  config = {
    deploy.targets.cirno = {
      nodeNames = singleton "cirno";
    };
    network.nodes.cirno = { meta, ... }: {
      imports = let
        tf = import (inputs.tf + "/modules");
      in [
        ../../../nixos.nix
        ./nixos.nix
        tf.nixos.oracle
        tf.nixos.ubuntu-linux # lustrate host image
      ];
    };
  };
}
