{ pkgs, network } @ args: let
  network' = import "${toString ./config}/deploy/${args.network}.nix";
  network = pkgs.lib.mapAttrs (_: node: nixos network' node) network';
  nodes = pkgs.lib.mapAttrs (_: node: node.config) network;
  nixos = network: host: (import (pkgs.path + "/nixos")) {
    inherit (pkgs.stdenv.hostPlatform) system;
    configuration = { lib, ... }: {
      imports = [host];

      config = {
        nixpkgs.pkgs = lib.mkDefault pkgs;
        _module.args = {
          inherit nodes;
          resources = network.resources or {};
        };
      };
    };
  };
in {
  inherit network nodes;
}
