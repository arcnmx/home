{ inputs ? (import ../ci/bootstrap.nix).inputs }: let
  channels = {
    paths = builtins.mapAttrs (_: i: i.outPath) {
      inherit (inputs) nixpkgs home-manager tf arc rust;
    };
    imports = {
      inherit (channels.paths) nixpkgs arc rust;
    };
    overlays = [
      channels.paths.arc
      channels.paths.rust
    ];
    nixPath = map (ch: "${ch}=${channels.imports.${ch}}") (builtins.attrNames channels.imports);
    nixpkgs = import channels.paths.nixpkgs {
      system = builtins.currentSystem or "x86_64-linux";
      inherit (channels.config.nixpkgs) config overlays;
    };
    config.nixpkgs = {
      config = import ./channels/nixpkgs.nix;
      overlays = map (p: import (p + "/overlay.nix")) channels.overlays;
    };
    pkgs = channels.nixpkgs;
  };
  inherit (channels) pkgs;
  inherit (pkgs) lib;
  hostname = config.deploy.local.hostName;
  metaConfig = { ... }: {
    config = {
      inherit channels;
      _module.args = {
        pkgs = lib.mkDefault pkgs;
      };
    };
  };
  eval = lib.evalModules {
    modules = [
      metaConfig
      ./modules/meta/default.nix
      ./meta.nix # main entry point?
    ];

    specialArgs = {
      inherit channels inputs;
      trusted = import ./trusted.nix { inherit lib; };
      # TODO?
    };
  };
  inherit (eval) config;
  host = config.network.nodes.${hostname};
in config // lib.optionalAttrs (hostname != null) {
  inherit host;
} // {
  switch = lib.optionalAttrs (hostname != null) host.run.switch // lib.mapAttrs (_: host: host.run.deploy) config.network.nodes;
} // channels
