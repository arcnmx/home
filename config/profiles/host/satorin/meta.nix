{ lib, ... }: with lib; {
  config = {
    deploy.targets.satorin = {
      nodeNames = singleton "satorin";
    };
    deploy.personal.hosts.satorin = { };
    network.nodes.satorin = { ... }: {
      imports = [
        ../../../nixos.nix
        ./nixos.nix
      ];
    };
  };
}
