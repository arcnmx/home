{ inputs ? (import ../ci/bootstrap.nix).inputs }: let
  channels = {
    imports = {
      inherit (inputs) nixpkgs arc rust;
    };
    overlays = [
      inputs.arc
      inputs.rust
    ];
    nixPath = map (ch: "${ch}=${channels.imports.${ch}}") (builtins.attrNames channels.imports);
    nixpkgs = import inputs.nixpkgs {
      system = builtins.currentSystem or "x86_64-linux";
      inherit (channels.config.nixpkgs) config overlays;
    };
    config.nixpkgs = {
      config = import ./channels/nixpkgs.nix;
      overlays = map (p: import (p + "/overlay.nix")) channels.overlays ++ [
        (import ../cfg/overlay)
      ];
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
      ../cfg
    ];

    specialArgs = {
      inherit channels inputs;
      trusted = import ./trusted.nix {
        inherit lib;
        ${if builtins.getEnv or (_: "") "HOME_TRUSTED" == "0" then "enable" else null} = false;
      };
      # TODO?
    };
  };
  inherit (eval) config;
  host = config.network.nodes.${hostname};
in config // lib.optionalAttrs (hostname != null) {
  inherit host inputs;
} // {
  switch = lib.optionalAttrs (hostname != null) host.run.switch // lib.mapAttrs (_: host: host.run.deploy) config.network.nodes;
  meta = config;
} // channels
