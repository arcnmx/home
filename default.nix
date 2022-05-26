{ }: let
  channels = import ./import.nix;
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
      ./config/modules/meta/default.nix
      ./config/meta.nix # main entry point?
    ];

    specialArgs = {
      inherit channels;
      trusted = import ./config/trusted.nix { inherit lib; };
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
