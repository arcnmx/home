{ pkgs ? (import ./. { }).pkgs
} @ args: with pkgs.lib; let
  network = networkName: let
    networkConfig = import "${toString ./config}/deploy/${networkName}.nix" { };
    network = mapAttrs (_: node: nixos networkConfig node) networkConfig;
    nodes = mapAttrs (_: node: node.config) network;
    nixos = network: host: (import (pkgs.path + "/nixos")) {
      inherit (pkgs) system;
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
    inherit nodes network;
  };
  networkNames = [
    "gensokyo"
  ];
in genAttrs networkNames network
