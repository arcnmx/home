{ meta, tf, config, pkgs, lib, ... }: with lib; let
  inherit (config.networking) domains;
in {
  config = {
    services.tailscale.enable = true;
    deploy.tf = let
      inherit (config.home.profileSettings.gensokyo) zone;
      domain = removeSuffix zone config.networking.fqdn;
    in {
      dns.records = mkIf (zone != null) {
        local_a = mkIf config.deploy.network.local.hasIpv4 {
          inherit zone domain;
          a.address = config.deploy.network.local.ipv4;
        };
        local_aaaa = mkIf (config.networking.enableIPv6 && config.deploy.network.local.hasIpv6) {
          inherit zone domain;
          aaaa.address = if config.deploy.network.ipv6.isGlobal.wan
            then config.deploy.network.wan.ipv6
            else config.deploy.network.local.ipv6;
        };
        lan_a = mkIf config.deploy.network.local.hasIpv4 {
          inherit zone;
          domain = "${config.networking.hostName}.local";
          a.address = config.deploy.network.local.ipv4;
        };
        lan_aaaa = mkIf (config.networking.enableIPv6 && config.deploy.network.local.hasIpv6) {
          inherit zone;
          domain = "${config.networking.hostName}.local";
          aaaa.address = config.deploy.network.local.ipv6;
        };
        wan_a = {
          inherit zone;
          domain = config.networking.hostName;
          a.address = if config.deploy.network.wan.hasIpv4
            then config.deploy.network.wan.ipv4
            else tf.resources.wan_a_lookup.refAttr "addrs[0]";
        };
        wan_aaaa = mkIf (config.networking.enableIPv6 && config.deploy.network.wan.hasIpv6) {
          inherit zone;
          domain = config.networking.hostName;
          aaaa.address = config.deploy.network.wan.ipv6;
        };
        ygg = mkIf config.services.yggdrasil.enable {
          inherit zone;
          domain = "${config.networking.hostName}.y";
          aaaa.address = config.services.yggdrasil.address;
        };
      };
      resources = {
        wan_a_lookup = mkIf (zone != null && !config.deploy.network.wan.hasIpv4) {
          provider = "dns";
          type = "a_record_set";
          dataSource = true;
          inputs = {
            host = config.networking.domain;
          };
        };
      };
    };
  };
}
