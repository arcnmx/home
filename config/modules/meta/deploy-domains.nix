{ pkgs, config, lib, ... }: with lib; let
  domainType = types.submodule ({ config, name, ... }: {
    options = {
      keyName = mkOption {
        type = types.nullOr types.str;
        default = null;
      };
      keyPath = mkOption {
        type = types.nullOr types.str;
        default = null;
      };
      pem = mkOption {
        type = types.nullOr types.str;
        default = null;
      };
      certPath = mkOption {
        type = types.nullOr types.path;
        default = mapNullable (pem: pkgs.writeText "${name}.pem" pem) config.pem;
      };
      url = mkOption {
        type = types.str;
        default = genUrl config.protocol config.fqdn config.port;
      };
      protocol = mkOption {
        type = types.str;
      };
      port = mkOption {
        type = types.coercedTo types.float toInt types.int;
        default = {
          http = 80;
          https = 443;
        }.${config.protocol};
      };
      fqdn = mkOption {
        type = types.str;
        default =
          if config.tld != null then "${optionalString (config.domain != null) "${config.domain}."}${config.tld}"
          else if config.reachable || config.bind == "localhost" || config.bind == "127.0.0.1" then "127.0.0.1"
          else throw "no fqdn for ${name}: ${toString config.domain}";
      };
      fqdnAliases = mkOption {
        type = types.listOf types.str;
        default = [ ];
      };
      tld = mkOption {
        type = types.nullOr types.str;
        default = null;
      };
      domain = mkOption {
        type = types.nullOr types.str;
        default = null;
      };
      bind = mkOption {
        type = types.nullOr types.str;
        apply = v: if v == "localhost" then "127.0.0.1" else v;
      };
      reachable = mkOption {
        type = types.bool;
        default = config.bind == "0.0.0.0" || config.bind == "::" || config.bind == "*" || config.bind == "";
      };
      out = {
        keyPath = mkOption {
          type = types.nullOr types.unspecified;
          default = mapNullable (keyName: config: config.secrets.files.${keyName}.path) config.keyName;
        };
      };
    };
    config.out = {
      keyPath = if config.keyPath != null
        then (_: config.keyPath)
        else if config.keyName != null then nixosConfig: nixosConfig.secrets.files.${config.keyName}.path
        else (_: null);
    };
  });
in {
  options.deploy.domains = mkOption {
    type = types.attrsOf (types.attrsOf domainType);
    default = { };
  };
}
