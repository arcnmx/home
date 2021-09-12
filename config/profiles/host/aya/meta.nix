{ lib, ... }: with lib; {
  config = {
    deploy.targets.aya = {
      nodeNames = singleton "aya";
    };
    network.nodes.aya = { modulesPath, ... }: {
      imports = [
        ../../../nixos.nix
        (modulesPath + "/installer/sd-card/sd-image.nix")
      ];

      networking = {
        hostName = "aya";
      };
    };
  };
}
