{ lib, ... }: with lib; {
  config = {
    deploy.targets.shanghai = {
      nodeNames = singleton "shanghai";
    };
    network.nodes.shanghai = { ... }: {
      imports = [
        ../../../nixos.nix
        ../../../../cfg/ddclient/deploy.nix
        ./nixos.nix
      ];
    };
  };
}
