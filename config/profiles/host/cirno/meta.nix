{ lib, inputs, ... }: with lib; {
  config = {
    deploy.targets.cirno = {
      nodeNames = singleton "cirno";
    };
    network.nodes.cirno = { meta, ... }: {
      imports = [
        ../../../nixos.nix
        ./nixos.nix
        inputs.tf.nixosModules.oracle
        inputs.tf.nixosModules.ubuntu-linux # lustrate host image
      ];
    };
  };
}
