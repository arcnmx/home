{ meta, tf, config, pkgs, lib, ... }: with lib; let
  inherit (meta.deploy) domains;
in {
  options.home = {
    profiles = {
      host.gensokyo = mkEnableOption "network: gensokyo";
    };
  };

  config = mkIf config.home.profiles.host.gensokyo {
    deploy.tf = let
      tld = findFirst (k: hasSuffix k config.networking.domain) null (mapAttrsToList (_: zone: zone.tld) tf.dns.zones);
      domain = removeSuffix tld "${config.networking.hostName}.${config.networking.domain}";
    in {
      dns.records = mkIf (tld != null) {
        local_a = mkIf config.deploy.network.local.hasIpv4 {
          inherit tld domain;
          a.address = config.deploy.network.local.ipv4;
        };
        local_aaaa = mkIf (config.networking.enableIPv6 && config.deploy.network.local.hasIpv6) {
          inherit tld domain;
          aaaa.address = config.deploy.network.local.ipv6;
        };
        wan_a = {
          inherit tld;
          domain = config.networking.hostName;
          a.address = if config.deploy.network.wan.hasIpv4
            then config.deploy.network.wan.ipv4
            else tf.resources.wan_a_lookup.refAttr "addrs[0]";
        };
        wan_aaaa = mkIf (config.networking.enableIPv6 && config.deploy.network.wan.hasIpv6) {
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
        wan_a_lookup = mkIf (tld != null && !config.deploy.network.wan.hasIpv4) {
          provider = "dns";
          type = "a_record_set";
          dataSource = true;
          inputs = {
            host = config.networking.domain;
          };
        };
        bitwarden_rs_token = mkIf config.services.bitwarden_rs.enable {
          provider = "random";
          type = "string";
          inputs = {
            length = 64;
          };
        };
        synapse_registration = mkIf config.services.matrix-synapse.enable {
          provider = "random";
          type = "string";
          inputs = {
            length = 64;
          };
        };
        synapse_macaroon = mkIf config.services.matrix-synapse.enable {
          provider = "random";
          type = "string";
          inputs = {
            length = 64;
          };
        };
      };
    };
    services = mkMerge [ {
      # common service configs and defaults
      taskserver = {
        ipLog = mkDefault true;
        requestLimit = mkDefault (1024*1024*16); # task sync doesn't know how to do things in pieces :<
      };
      gitolite = {
        enableGitAnnex = mkDefault true;
      };
      bitwarden_rs.config = {
        webVaultEnabled = mkDefault true;
        signupsAllowed = mkDefault false;
        websocketEnabled = mkDefault true;
        rocketEnv = mkDefault "production";
        dataFolder = "/var/lib/bitwarden_rs";
        databaseUrl = mkDefault "${config.services.bitwarden_rs.config.dataFolder}/db.sqlite3";
      };
      matrix-synapse = {
        rc_messages_per_second = mkDefault "0.1";
        rc_message_burst_count = mkDefault "25.0";
        url_preview_enabled = mkDefault true;
        enable_registration = mkDefault false;
        enable_metrics = mkDefault false;
        report_stats = mkDefault false;
        dynamic_thumbnails = mkDefault true;
        allow_guest_access = mkDefault true;
        # synapse seems to have a lot of performance issues related to presence..?
        extraConfig = ''
          suppress_key_server_warning: true
          use_presence: false
        '';
      };
      prosody = {
        allowRegistration = mkDefault false;
        c2sRequireEncryption = mkDefault true;
        s2sRequireEncryption = mkDefault true;
        s2sSecureAuth = mkDefault true; # server cert validation
        #s2sInsecureDomains = [ ]; # secure auth exceptions
        authentication = mkDefault "internal_hashed";
        extraConfig = ''
          modules_disabled = {
            "offline";
          }
        '';
        xmppComplianceSuite = mkDefault false; # TODO: configure uploadHttp
      };
      nginx = {
        package = mkDefault pkgs.nginxMainline;
        recommendedGzipSettings = mkDefault true;
        recommendedOptimisation = mkDefault true;
        recommendedProxySettings = mkDefault true;
        recommendedTlsSettings = mkDefault true;
      };
      bitlbee = {
        plugins = with pkgs; [ bitlbee-discord bitlbee-steam ];
        libpurple_plugins = mkDefault pkgs.purple-plugins-arc;
        authMode = mkDefault "Registered";
      };
      postgresql = mkMerge [
        (mkIf (config.services.prosody.enable /*&& config.services.prosody.sql.driver == "PostgreSQL"*/) {
          ensureDatabases = singleton "prosody";
          ensureUsers = singleton {
            name = "prosody";
            ensurePermissions = {
              "DATABASE prosody" = "ALL PRIVILEGES";
            };
          };
        })
        (mkIf (config.services.bitwarden_rs.enable && config.services.bitwarden_rs.dbBackend == "postgresql") {
          ensureDatabases = singleton "bitwarden_rs";
          ensureUsers = singleton {
            name = "bitwarden_rs";
            ensurePermissions = {
              "DATABASE bitwarden_rs" = "ALL PRIVILEGES";
            };
          };
        })
      ];
    } {
      matrix-synapse = {
        extraConfigFiles = singleton config.secrets.files.matrix-synapse-secrets.path;
        bridges = {
          hangouts = {
            port = 32063;
          };
          discord = {
            port = 32065;
          };
          puppet-discord = {
            port = 32065;
          };
          whatsapp = {
            port = 32067;
          };
          irc = {
            port = 32068;
          };
        };
        database_type = mkIf config.services.postgresql.enable "psycopg2";
      };
      bitwarden_rs = {
        dbBackend = mkIf config.services.postgresql.enable "postgresql";
        config = {
          #adminToken = tf.resources.bitwarden_rs_token.getAttr "result"; # NOTE: keep unset unless admin page is needed
          databaseUrl = mkIf config.services.postgresql.enable "postgresql://bitwarden_rs@/bitwarden_rs";
        };
      };
      #gitolite.adminPubkey = config.secrets.files.ssh_key.getAttr "public_key_openssh";
      nginx.virtualHosts = with meta.deploy.domains; let
        extraParameters = [ "reuseport" "deferred" ];
        hostName = config.networking.hostName;
        host = misc.${hostName};
      in mkIf (misc ? ${hostName}) {
        ${host.url} = {
          serverName = host.fqdn;
          addSSL = true;
          listen = [
            { addr = host.bind; port = 443; ssl = true; inherit extraParameters; }
            { addr = host.bind; port = 80; ssl = false; inherit extraParameters; }
          ];
          default = true;
          sslCertificate = host.certPath;
          sslCertificateKey = host.out.keyPath config;
          serverAliases = host.fqdnAliases;
          locations."/" = {
            return = "307 http://sator.in";
          };
        };
      };
    } {
      # domains, routes and cert garbage ahead
      bitwarden_rs.config = with domains.bitwarden_rs; {
        domain = public.url;
        rocketPort = private.port;
        rocketAddress = private.bind;
        websocketPort = private-websocket.port;
        websocketAddress = private-websocket.bind;
      };
      taskserver = with domains.taskserver; {
        fqdn = public.fqdn;
        listenPort = public.port;
        listenHost = public.bind;
        pki.manual = {
          server = {
            key = public.out.keyPath config;
            cert = public.certPath;
          };
          ca.cert = ca.certPath;
        };
      };
      prosody.virtualHosts = with domains.prosody; {
        ${vanity.fqdn} = {
          enabled = true;
          domain = vanity.fqdn;
          ssl = {
            key = vanity.out.keyPath config;
            cert = vanity.certPath;
          };
        };
      };
      matrix-synapse = with domains.matrix-synapse; {
        server_name = vanity.fqdn;
        public_baseurl = public.url;
        listeners = [ {
          port = private.port;
          bind_address = private.bind;
          tls = false;
          x_forwarded = true;
          resources = [
            { names = [ "client" ]; compress = true; }
          ];
        } {
          port = private-federation.port;
          bind_address = private-federation.bind;
          tls = false;
          x_forwarded = true;
          resources = [
            { names = [ "federation" ]; compress = true; }
          ];
        } ];
      };
      nginx.virtualHosts = with domains; {
        ${bitwarden_rs.public.url} = with bitwarden_rs; mkIf config.services.bitwarden_rs.enable {
          serverName = public.fqdn;
          onlySSL = true;
          sslCertificate = public.certPath;
          sslCertificateKey = public.out.keyPath config;
          listen = [ { addr = public.bind; port = public.port; ssl = true; } ];
          locations = {
            "/" = {
              proxyPass = private.url;
            };
            "/notifications/hub" = {
              proxyPass = private-websocket.url;
              proxyWebsockets = true;
            };
            "/notifications/hub/negotiate" = {
              proxyPass = private.url;
            };
            "/admin" = {
              proxyPass = mkIf (config.services.bitwarden_rs.config ? adminToken) private.url;
            };
          };
        };
        ${matrix-synapse.public.url} = with matrix-synapse; mkIf config.services.matrix-synapse.enable {
          serverName = public.fqdn;
          addSSL = true;
          sslCertificate = public.certPath;
          sslCertificateKey = public.out.keyPath config;
          listen = [ { addr = public.bind; port = public.port; ssl = true; } ];
          locations = {
            "/_matrix" = {
              proxyPass = private.url;
            };
            "/mautrix-hangouts/" = mkIf config.services.matrix-synapse.bridges.hangouts.enable {
              proxyPass = "http://127.0.0.1:${toString config.services.matrix-synapse.bridges.hangouts.port}/mautrix-hangouts/";
            };
          };
        };
        ${matrix-synapse.federation.url} = with matrix-synapse; mkIf config.services.matrix-synapse.enable {
          serverName = federation.fqdn;
          onlySSL = true;
          sslCertificate = federation.certPath;
          sslCertificateKey = federation.out.keyPath config;
          listen = [ { addr = federation.bind; port = federation.port; ssl = true; } ];
          locations."/" = {
            proxyPass = private-federation.url;
          };
        };
        ${matrix-synapse.vanity.url} = with matrix-synapse; mkIf config.services.matrix-synapse.enable {
          serverName = vanity.fqdn;
          addSSL = true;
          sslCertificate = vanity.certPath;
          sslCertificateKey = vanity.out.keyPath config;
          listen = [
            { addr = vanity.bind; port = 443; ssl = true; }
            { addr = vanity.bind; port = 80; ssl = false; }
          ];
          locations."/.well-known/matrix/" = let
            server = pkgs.writeTextFile {
              name = "matrix-well-known-server.json";
              destination = "/server";
              text = builtins.toJSON {
                "m.server" = "${federation.fqdn}:${toString federation.port}";
              };
            };
            client = pkgs.writeTextFile {
              name = "matrix-well-known-client.json";
              destination = "/client";
              text = builtins.toJSON {
                "m.homeserver".base_url = public.url;
                "m.identity_server".base_url = "https://vector.im"; # ?
              };
            };
            matrix = pkgs.symlinkJoin {
              name = "matrix-well-known";
              paths = [ server client ];
            };
          in {
            alias = "${matrix}/";
            # ACAO required to allow element-web on any URL to request this json file
            extraConfig = ''
              add_header Content-Type application/json;
              add_header Access-Control-Allow-Origin *;
            '';
          };
        };
      };
    } ];
    networking.firewall.allowedTCPPorts = singleton 80 ++ map (domain: domain.port) (with domains; [
      taskserver.public
      bitwarden_rs.public
      matrix-synapse.public matrix-synapse.federation
      prosody.public prosody.federation
    ]);
    # hacky replacement for ensureDatabases
    systemd.services.postgresql.postStart = mkIf (config.services.postgresql.enable) (mkAfter ''
      $PSQL -tAc "SELECT 1 FROM pg_database WHERE datname = 'matrix-synapse'" | grep -q 1 ||
        $PSQL -tAc 'CREATE DATABASE "matrix-synapse" TEMPLATE template0 LC_COLLATE = "C" LC_CTYPE = "C"'
      $PSQL -tAc "SELECT 1 FROM pg_roles WHERE rolname='matrix-synapse'" | grep -q 1 ||
        $PSQL -tAc 'CREATE USER "matrix-synapse"'
      $PSQL -tAc 'GRANT ALL PRIVILEGES ON DATABASE "matrix-synapse" TO "matrix-synapse"'
    '');
    secrets.files = with meta.deploy.domains; mkMerge [ {
      matrix-synapse-secrets = mkIf config.services.matrix-synapse.enable {
        owner = "matrix-synapse";
        text = ''
          registration_shared_secret: "${tf.resources.synapse_registration.refAttr "result"}"
          macaroon_secret_key: "${tf.resources.synapse_macaroon.refAttr "result"}"
        '';
      };
      ${taskserver.public.fqdn} = mkIf config.services.taskserver.enable {
        owner = mkForce config.services.taskserver.user;
      };
    } (mapListToAttrs (fqdn: nameValuePair fqdn.name {
      owner = config.services.nginx.user;
      text = config.deploy.tf.import.common.acme.certs.${fqdn.name}.out.importPrivateKeyPem;
    }) (filter (item: item.value) [
      (nameValuePair taskserver.public.fqdn config.services.taskserver.enable)
      (nameValuePair bitwarden_rs.public.fqdn config.services.bitwarden_rs.enable)
      (nameValuePair prosody.vanity.fqdn config.services.prosody.enable)
      (nameValuePair matrix-synapse.vanity.fqdn config.services.matrix-synapse.enable)
      (nameValuePair matrix-synapse.public.fqdn config.services.matrix-synapse.enable)
      (nameValuePair matrix-synapse.federation.fqdn config.services.matrix-synapse.enable)
      (nameValuePair misc.mystia.fqdn config.home.profiles.host.mystia)
    ])) ];
  };
}
