{ tf, config, pkgs, lib, ... }: with lib; let
  inherit (config.networking) domains bindings;
in {
  config = mkIf config.home.profiles.host.gensokyo {
    deploy.tf = {
      dns.records = mkIf config.services.prosody.enable {
        prosody-server = {
          inherit (domains.xmpp) zone domain;
          srv = {
            service = "xmpp-server";
            proto = "tcp";
            target = domains.xmpp-web.fqdn;
            port = bindings.prosody-federation.port;
          };
        };
        prosody-client = {
          inherit (domains.xmpp) zone domain;
          srv = {
            service = "xmpp-client";
            proto = "tcp";
            target = domains.xmpp-web.fqdn;
            port = bindings.prosody-client.port;
          };
        };
      };
    };
    services = {
      prosody = {
        package = let
          package = pkgs.prosody.override (old: {
            withExtraLibs = old.withExtraLibs ++ singleton pkgs.luaPackages.luadbi-postgresql;
          });
        in mkIf config.services.postgresql.enable package;
        bindings = {
          c2s = bindings.prosody-client;
          s2s = bindings.prosody-federation;
          web = bindings.prosody-web-private;
        };
        domains = {
          web = domains.xmpp-web;
          components = {
            upload = domains.xmpp-upload;
            muc = domains.xmpp-muc;
          };
          virtual = [ domains.xmpp ];
        };
        muc = singleton {
          domainRef = domains.xmpp-muc;
          restrictRoomCreation = true;
        };
        allowRegistration = mkDefault false;
        c2sRequireEncryption = mkDefault true;
        s2sRequireEncryption = mkDefault true;
        s2sSecureAuth = mkDefault true; # server cert validation
        #s2sInsecureDomains = [ ]; # secure auth exceptions
        authentication = mkDefault "internal_hashed";
        extraConfig = mkMerge [ ''
          modules_disabled = {
            "offline";
          }
        '' (mkIf config.services.postgresql.enable ''
          storage = "sql"
          sql = {
            driver = "PostgreSQL";
            host = "";
            database = "prosody";
            username = "prosody";
          }
        '') ];
      };
      postgresql = mkIf (config.services.prosody.enable /*&& config.services.prosody.sql.driver == "PostgreSQL"*/) {
        ensureDatabases = singleton "prosody";
        ensureUsers = singleton {
          name = "prosody";
          ensurePermissions = {
            "DATABASE prosody" = "ALL PRIVILEGES";
          };
        };
      };
      nginx.virtualHosts.${domains.xmpp-web.key} = mkIf config.services.prosody.enable {
        locations = {
          "/" = {
            proxyPassConnection = {
              binding = bindings.prosody-web-private;
            };
          };
        };
      };
    };

    networking = {
      bindings = {
        prosody-federation = {
          port = 5269;
          address = "*";
        };
        prosody-client = {
          port = 5222;
          address = "*";
        };
        prosody-components = {
          port = 5347;
          address = "*";
        };
        prosody-web-private = {
          port = 5280;
        };
      };
      domains = {
        xmpp-muc = {
          ssl.enable = false;
          inherit (config.services.prosody) enable;
          domain = "conference.xmpp";
          nginx.enable = false;
          # TODO: option to make this (and other domains) a cname
        };
        xmpp-upload = {
          ssl.enable = false;
          inherit (config.services.prosody) enable;
          domain = "upload.xmpp";
          nginx.enable = false;
        };
        xmpp = {
          inherit (config.services.prosody) enable;
          nginx.enable = false;
          ssl = {
            secret.owner = config.services.prosody.user;
            fqdnAliases = [
              domains.xmpp-muc.fqdn domains.xmpp-upload.fqdn
            ];
          };
        };
        xmpp-web = {
          inherit (config.services.prosody) enable;
          domain = "xmpp";
          sslOnly = true;
        };
      };
    };
  };
}
