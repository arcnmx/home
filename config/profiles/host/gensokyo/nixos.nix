{ tf, config, lib, ... }: with lib; {
  options.home = {
    profiles = {
      host.gensokyo = mkEnableOption "network: gensokyo";
    };
  };

  config.deploy.tf = let
    tld = findFirst (k: hasSuffix k config.networking.domain) null (mapAttrsToList (_: zone: zone.tld) tf.dns.zones);
    domain = removeSuffix tld "${config.networking.hostName}.${config.networking.domain}";
  in mkIf config.home.profiles.host.gensokyo {
    dns.records = mkIf (tld != null) {
      local_a = mkIf (config.deploy.network.local.ipv4 != null) {
        inherit tld domain;
        a.address = config.deploy.network.local.ipv4;
      };
      local_aaaa = mkIf (config.networking.enableIPv6 && config.deploy.network.local.ipv6 != null) {
        inherit tld domain;
        aaaa.address = config.deploy.network.local.ipv6;
      };
      wan_a = {
        inherit tld;
        domain = config.networking.hostName;
        a.address = if config.deploy.network.wan.ipv4 != null
          then config.deploy.network.wan.ipv4
          else tf.resources.wan_a_lookup.refAttr "addrs[0]";
      };
      wan_aaaa = mkIf (config.networking.enableIPv6 && config.deploy.network.wan.ipv6 != null) {
        inherit tld;
        domain = config.networking.hostName;
        aaaa.address = config.deploy.network.wan.ipv6;
      };
      ygg = mkIf config.services.yggdrasil.enable {
        inherit tld;
        domain = "${config.networking.hostName}.y";
        aaaa.address = config.services.yggdrasil.address;
      };
    };
    resources = {
      wan_a_lookup = mkIf (tld != null && config.deploy.network.wan.ipv4 == null) {
        provider = "dns";
        type = "a_record_set";
        dataSource = true;
        inputs = {
          host = config.networking.domain;
        };
      };
    };
  };
}
