{ lib, ... }: with lib; {
  config = {
    deploy.targets.shanghai = {
      nodeNames = singleton "shanghai";
    };
    deploy.personal.hosts.shanghai = { };
    network.nodes.shanghai = { ... }: {
      imports = [
        ../../../nixos.nix
        ./nixos.nix
      ];
    };
  };
}
