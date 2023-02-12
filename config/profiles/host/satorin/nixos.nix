{ tf, pkgs, config, lib, ... }: with lib; {
  imports = [
    ../../../../cfg/gensokyo.nix
    ../../../../nodes/satorin
  ];

  config = {
    deploy.network.local.ipv4 = "10.1.1.64";
    services.yggdrasil = mkIf tf.state.enable {
      privateKey = config.secrets.files.ygg-key.path;
    };
    secrets.files.ygg-key = mkIf (tf.state.enable && config.services.yggdrasil.enable) {
      text = tf.variables.ygg-key.ref;
      group = config.services.yggdrasil.group;
      mode = "0440";
    };
    deploy.tf.variables.ygg-key.bitw.name = "yggdrasil-satorin";
  };
}
