{ name, meta, tf, pkgs, config, lib, ... }: with lib; let
  inherit (config.networking) enableIPv6;
  cfg = config.services.ddclient;
  tokenPlaceholder = "@PASSWORD@";
  replaceSecret = token: replaceStrings [ tokenPlaceholder ] [ token ];
  confText = config.environment.etc."ddclient.conf".text;
  zoneId = tf.dns.zones.${cfg.zone}.cloudflare.id;
  isCloudflare = cfg.protocol == "cloudflare";
  domainName = domain: "dyndns_" + replaceStrings [ "-" "." ] [ "" "" ] domain;
in {
  options.services.ddclient.package = mkOption {
    type = types.package;
    default = pkgs.ddclient;
  };
  config = mkIf (config.home.profiles.personal && config.services.ddclient.enable) {
    deploy.tf = {
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
    secrets.files.ddclient-config = mkIf isCloudflare {
      text = replaceSecret (tf.resources.ddclient-cloudflare-key.refAttr "value") confText;
    };
    services.ddclient = mkMerge [ {
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
    } (mkIf tf.state.enable {
      configFile = config.secrets.files.ddclient-config.path;
      password = tokenPlaceholder;
    }) ];
    systemd.services.ddclient = {
      serviceConfig = {
        TimeoutStartSec = 90;
        ExecStart = mkForce "${cfg.package}/bin/ddclient -file /run/ddclient/ddclient.conf";
      };
    };
  };
}
