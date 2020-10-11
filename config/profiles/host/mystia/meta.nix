{ lib, ... }: with lib; {
  config = {
    deploy.targets.mystia = {
      nodeNames = singleton "mystia";
    };
    network.nodes.mystia = { modulesPath, ... }: {
      imports = [
        ../../../nixos.nix
        (modulesPath + "/virtualisation/digital-ocean-config.nix")
      ];

      virtualisation.digitalOcean = {
        rebuildFromUserData = false;
      };
      networking = {
        hostName = "mystia";
      };
    };
  };
}
