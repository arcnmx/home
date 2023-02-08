{ name, meta, tf, pkgs, config, lib, ... }: with lib; let
  inherit (config.networking) enableIPv6;
  cfg = config.services.ddclient;
  zoneId = tf.dns.zones.${cfg.zone}.cloudflare.id;
  isCloudflare = cfg.protocol == "cloudflare";
  domainName = domain: "dyndns_" + replaceStrings [ "-" "." ] [ "" "" ] domain;
  hasSecret = cfg.enable && isCloudflare && tf.state.enable;
in {
  config = {
    deploy.tf = mkIf cfg.enable {
      dns.records = listToAttrs (concatMap (domain: [
        # ddclient requires that records already exist in order to change them
        (nameValuePair "dyndns-${domain}-a" {
          enable = isCloudflare;
          name = domainName domain;
          inherit (cfg) zone;
          domain = removeSuffix ".${cfg.zone}" domain;
          a.address = "127.0.0.1";
          ttl = 60 * 5;
        })
        (nameValuePair "dyndns-${domain}-aaaa" {
          enable = enableIPv6 && isCloudflare;
          name = domainName domain;
          inherit (cfg) zone;
          domain = removeSuffix ".${cfg.zone}" domain;
          aaaa.address = "::1";
          ttl = 60 * 5;
        })
      ]) cfg.domains);
      resources = {
        ddclient-cloudflare-key = {
          enable = isCloudflare;
          provider = "cloudflare";
          type = "api_token";
          inputs = {
            name = "${meta.deploy.idTag}_${config.networking.hostName}_ddclient";
            policy = singleton {
              # https://developers.cloudflare.com/api/tokens/create/permissions
              permission_groups = [
                "c8fed203ed3043cba015a93ad1616f1f" # Zone Read
                "82e64a83756745bbbb1c9c2701bf816b" # DNS Read
                "4755a26eedb94da69e1066d98aa820be" # DNS Write
              ];
              resources = {
                "com.cloudflare.api.account.zone.${zoneId}" = "*";
              };
            };
          };
        };
      } // listToAttrs (concatMap (domain: [
        # the addresses change when ddclient runs
        (nameValuePair "record_${domainName domain}_A" {
          lifecycle.ignoreChanges = [ "value" ];
        })
        (nameValuePair "record_${domainName domain}_AAAA" {
          lifecycle.ignoreChanges = [ "value" ];
        })
      ]) cfg.domains);
      deploy.systems.${name}.triggers.switch = listToAttrs (concatMap (domain: let
        recordA = tf.dns.records."dyndns-${domain}-a";
        recordAAAA = tf.dns.records."dyndns-${domain}-aaaa";
      in [
        (nameValuePair "dyndns-${domain}-a" (mkIf recordA.enable (recordA.out.resource.refAttr "id")))
        (nameValuePair "dyndns-${domain}-aaaa" (mkIf recordAAAA.enable (recordAAAA.out.resource.refAttr "id")))
      ]) cfg.domains);
    };
    secrets.files.ddclient-secret = mkIf hasSecret {
      text = tf.resources.ddclient-cloudflare-key.refAttr "value";
    };
    services.ddclient = {
      package = pkgs.ddclient-develop;
      quiet = true;
      username = mkIf isCloudflare "token";
      use = "no";
      domains = mkDefault [ ]; # why the hell is `[""]` the default???
      extraConfig = mkMerge [ (mkIf enableIPv6 ''
        usev6=webv6, webv6=https://ipv6.nsupdate.info/myip
      '') ''
        usev4=webv4, webv4=https://ipv4.nsupdate.info/myip
        max-interval=1d
      '' ];
      passwordFile = mkIf hasSecret config.secrets.files.ddclient-secret.path;
    };
    systemd.services.ddclient = mkIf cfg.enable {
      serviceConfig = {
        TimeoutStartSec = 90;
        LogFilterPatterns = [
          "~WARNING"
        ];
      };
    };
  };
}
