{ tf, config, lib, ... }: with lib; let
  nixosConfig = config;
  enabledDomains = filterAttrs (_: d: d.enable) config.networking.domains;
  sslDomains = filterAttrs (_: d: d.ssl.enable && d.ssl.secret.enable) enabledDomains;
  sslModule = domain: { config, ... }: {
    options = {
      secret = {
        enable = mkEnableOption "ssl secret" // { default = true; };
        owner = mkOption {
          type = types.str;
        };
        group = mkOption {
          type = types.str;
          default = "keys";
        };
      };
    };
    config = {
      enable = mkDefault true;
      secret = {
        owner = mkIf (domain.nginx.enable && nixosConfig.services.nginx.enable) (mkDefault nixosConfig.services.nginx.user);
        group = mkIf nixosConfig.services.nginx.enable (mkDefault nixosConfig.services.nginx.group);
      };
    };
  };
  domainModule = { config, name, ... }: {
    options = {
      ssl = mkOption {
        type = types.submodule (sslModule config);
      };
    };
    config = {
      ssl = {
        certPath = mkIf config.ssl.enable nixosConfig.secrets.files."${config.fqdn}.pem".path;
        keyPath = mkIf config.ssl.enable nixosConfig.secrets.files.${config.fqdn}.path;
      };
    };
  };
in {
  options = {
    networking.domains = mkOption {
      type = types.attrsOf (types.submodule domainModule);
    };
  };
  config = {
    deploy.tf = {
      dns.records = mkMerge (mapAttrsToList (attr: domain: {
        "${domain.fqdn}-a" = {
          inherit (domain) zone domain;
          a.address = config.deploy.network.wan.ipv4;
        };
        "${domain.fqdn}-aaaa" = mkIf domain.enableIPv6 {
          inherit (domain) zone domain;
          aaaa.address = config.deploy.network.wan.ipv6;
        };
      }) enabledDomains);
      acme.certs = mapAttrs' (attr: domain: nameValuePair domain.fqdn {
        dnsNames = singleton domain.ssl.fqdn ++ domain.ssl.fqdnAliases;
      }) sslDomains;
    };
    secrets.files = foldAttrList (mapAttrsToList (attr: domain: {
      ${domain.fqdn} = {
        text = tf.acme.certs.${domain.fqdn}.out.refPrivateKeyPem;
        inherit (domain.ssl.secret) owner group;
        mode = "0440";
      };
      "${domain.fqdn}.pem" = {
        text = tf.acme.certs.${domain.fqdn}.out.refFullchainPem;
        inherit (domain.ssl.secret) owner group;
        mode = "0444";
      };
    }) sslDomains);
  };
}
