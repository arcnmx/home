{ tf, config, pkgs, lib, ... }: with lib; {
  imports = [
    ../../../../cfg/gensokyo.nix
    ../../../../nodes/shanghai
  ];

  config = {
    deploy.network.local.ipv4 = "10.1.1.32";
    systemd.network.networks.br = {
      address = [ "${config.deploy.network.local.ipv4}/24" ];
    };
    services.yggdrasil = mkIf tf.state.enable {
      privateKey = config.secrets.files.ygg-key.path;
    };
    secrets.files.ygg-key = mkIf (tf.state.enable && config.services.yggdrasil.enable) {
      text = tf.variables.ygg-key.ref;
    };
    deploy.tf = {
      variables.ygg-key.bitw.name = "yggdrasil-shanghai";
      dns.records = mkIf (config.home.profileSettings.gensokyo.zone != null) {
        hourai = {
          inherit (tf.dns.records.local_a) zone;
          domain = "hourai";
          a.address = "10.1.1.36";
        };
      };
    };
  };
}
