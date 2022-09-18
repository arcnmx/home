{ lib, ... }: with lib; {
  config = {
    deploy.targets.nue = {
      nodeNames = singleton "nue";
    };
    deploy.personal.hosts.nue = { };
    network.nodes.nue = { ... }: {
      imports = [
        ../../../nixos.nix
        ./nixos.nix
      ];
    };
  };
}
