{ }: let
  channels = import ./import.nix;
  inherit (channels) pkgs;
  inherit (pkgs) lib;
  hostname = if builtins.getEnv "HOME_HOSTNAME" != "" then builtins.getEnv "HOME_HOSTNAME" else null;
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
      # TODO?
    };
  };
  inherit (eval) config;
  host = config.network.nodes.${hostname};
in config // lib.optionalAttrs (hostname != null) {
  inherit host;
} // {
  switch = lib.optionalAttrs (hostname != null) host.deploy.run.switch // lib.mapAttrs (_: host: host.deploy.run.deploy) config.network.nodes;
} // channels
