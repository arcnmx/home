{ tf, config, pkgs, lib, ... }: with lib; let
  inherit (config.networking) domains bindings;
in {
  config = {
    deploy.tf = {
      dns.records = mkIf config.services.matrix-synapse.enable {
        matrix-synapse = {
          inherit (domains.matrix-discovery) zone domain;
          srv = {
            service = "matrix";
            proto = "tcp";
            target = domains.matrix-federation.fqdn;
            port = domains.matrix-federation.bindings.https4.port;
          };
        };
      };
      resources = {
        synapse_registration = mkIf config.services.matrix-synapse.enable {
          provider = "random";
          type = "password";
          inputs = {
            length = 64;
          };
        };
        synapse_macaroon = mkIf config.services.matrix-synapse.enable {
          provider = "random";
          type = "password";
          inputs = {
            length = 64;
          };
        };
        matrix-appservice-irc-passkey = mkIf config.services.matrix-appservices.matrix-appservice-irc.enable {
          provider = "tls";
          type = "private_key";
          inputs = {
            algorithm = "RSA";
            rsa_bits = 2048;
          };
        };
      };
    };
    services = {
      matrix-synapse = {
        extraConfigFiles = singleton config.secrets.files.matrix-synapse-secrets.path;
        domains = {
          discovery = domains.matrix-discovery;
          public = domains.matrix-client;
          listeners = {
            private-client = {
              binding = bindings.synapse-private-client;
              tls = false;
              x_forwarded = true;
              resources = [
                { names = [ "client" ]; compress = true; }
              ];
            };
            private-federation = {
              binding = bindings.synapse-private-federation;
              tls = false;
              x_forwarded = true;
              resources = [
                { names = [ "federation" ]; compress = true; }
              ];
            };
          };
        };
        settings = {
          database = mkIf config.services.postgresql.enable {
            name = "psycopg2";
          };

          #rc_messages_per_second = mkDefault "0.5";
          #rc_message_burst_count = mkDefault 25;
          max_upload_size = mkDefault "128M";
          url_preview_enabled = mkDefault true;
          enable_registration = mkDefault false;
          enable_metrics = mkDefault false;
          report_stats = mkDefault false;
          dynamic_thumbnails = mkDefault true;
          allow_guest_access = mkDefault true;
          suppress_key_server_warning = mkDefault true;
          enable_group_creation = mkDefault true;
        };
      };
      matrix-appservices = {
        matrix-appservice-irc.binding = bindings.matrix-appservice-irc;
        mautrix-whatsapp = {
          binding = bindings.mautrix-whatsapp;
          bridge = {
            permissions = {
              "@arc:${config.services.matrix-synapse.settings.server_name}" = "admin";
            };
          };
        };
        mautrix-hangouts = {
          binding = bindings.mautrix-hangouts;
          registration.pushEphemeral = true;
          appservice.maxBodySize = 4;
          logging.root.handlers = [ "console" ];
          bridge = {
            displayname_template = "{full_name}";
            permissions = {
              "@arc:${config.services.matrix-synapse.settings.server_name}" = "admin";
            };
            web.auth = {
              public = domains.matrix-client.url + "/mautrix-hangouts/";
              prefix = "/mautrix-hangouts";
            };
          };
        };
        mautrix-googlechat = {
          binding = bindings.mautrix-googlechat;
          registration.pushEphemeral = true;
          appservice.maxBodySize = 4;
          logging.root.handlers = [ "console" ];
          bridge = {
            displayname_template = "{full_name}";
            permissions = {
              "@arc:${config.services.matrix-synapse.settings.server_name}" = "admin";
            };
            web.auth = {
              public = domains.matrix-client.url + "/mautrix-googlechat/";
              prefix = "/mautrix-googlechat";
            };
          };
        };
        mx-puppet-discord = {
          package = pkgs.mx-puppet-discord-develop;
          binding = bindings.mx-puppet-discord;
          registrationPrefix = "_discord_";
          database.filename = "mx-puppet-discord.db";
        };
      };
      nginx.virtualHosts = {
        ${domains.matrix-client.key} = mkIf config.services.matrix-synapse.enable {
          locations = {
            "/_matrix" = {
              proxyPassConnection.binding = bindings.synapse-private-client;
              extraConfig = ''
                proxy_read_timeout 180s;
              '';
            };
            "/mautrix-hangouts/" = mkIf config.services.matrix-appservices.mautrix-hangouts.enable {
              proxyPassConnection = {
                extraUrlArgs.path = config.services.matrix-appservices.mautrix-hangouts.bridge.web.auth.prefix + "/";
                binding = config.services.matrix-appservices.mautrix-hangouts.binding;
              };
            };
            "/mautrix-googlechat/" = mkIf config.services.matrix-appservices.mautrix-googlechat.enable {
              proxyPassConnection = {
                extraUrlArgs.path = config.services.matrix-appservices.mautrix-googlechat.bridge.web.auth.prefix + "/";
                binding = config.services.matrix-appservices.mautrix-googlechat.binding;
              };
            };
            # TODO: "/" = { ? };
          };
          extraConfig = ''
            keepalive_requests 100000;
            keepalive_timeout 25s;
          '';
        };
        ${domains.matrix-federation.key} = mkIf config.services.matrix-synapse.enable {
          locations."/" = {
            proxyPassConnection.binding = bindings.synapse-private-federation;
            extraConfig = ''
              proxy_read_timeout 240s;
            '';
          };
        };
        ${domains.matrix-discovery.key} = mkIf config.services.matrix-synapse.enable {
          locations."/.well-known/matrix/" = let
            server = pkgs.writeTextFile {
              name = "matrix-well-known-server.json";
              destination = "/server";
              text = builtins.toJSON {
                "m.server" = "${domains.matrix-federation.fqdn}:${toString domains.matrix-federation.bindings.https4.port}";
              };
            };
            client = pkgs.writeTextFile {
              name = "matrix-well-known-client.json";
              destination = "/client";
              text = builtins.toJSON {
                "m.homeserver".base_url = domains.matrix-client.url;
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
    };
    services.postgresql = mkIf config.services.matrix-synapse.enable {
      ensureUsers = singleton {
        name = "matrix-synapse";
      };
    };
    systemd.services.postgresql = mkIf (config.services.matrix-synapse.enable && config.services.postgresql.enable) {
      # hacky replacement for ensureDatabases
      postStart = mkAfter ''
        $PSQL -tAc "SELECT 1 FROM pg_database WHERE datname = 'matrix-synapse'" | grep -q 1 ||
          $PSQL -tAc 'CREATE DATABASE "matrix-synapse" TEMPLATE template0 LC_COLLATE = "C" LC_CTYPE = "C"'
        $PSQL -tAc 'GRANT ALL PRIVILEGES ON DATABASE "matrix-synapse" TO "matrix-synapse"'
      '';
    };
    secrets.files = {
      matrix-synapse-secrets = mkIf config.services.matrix-synapse.enable {
        owner = "matrix-synapse";
        text = ''
          registration_shared_secret: "${tf.resources.synapse_registration.refAttr "result"}"
          macaroon_secret_key: "${tf.resources.synapse_macaroon.refAttr "result"}"
        '';
      };
      matrix-appservice-irc-passkey = mkIf config.services.matrix-appservices.matrix-appservice-irc.enable {
        owner = config.services.matrix-appservices.matrix-appservice-irc.user;
        source = tf.resources.matrix-appservice-irc-passkey.refAttr "filename";
      };
    };

    networking = {
      bindings = {
        synapse-private-client = { };
        synapse-private-federation = { };
        mautrix-hangouts = {
          port = 32063;
        };
        mautrix-googlechat = {
          port = 32064;
        };
        mx-puppet-discord = {
          port = 32065;
        };
        mautrix-whatsapp = {
          port = 32067;
        };
        matrix-appservice-irc = {
          port = 32068;
        };
      };
      domains = {
        matrix-client = {
          inherit (config.services.matrix-synapse) enable;
          domain = "matrix";
          bindings = genAttrs [ "https4" "https6" ] (_: {
            nginx.extraParameters = [ "http2" ];
          });
        };
        matrix-federation = {
          inherit (config.services.matrix-synapse) enable;
          domain = "matrix";
          sslOnly = true;
          bindings.https4.port = 8448;
        };
        matrix-discovery = {
          inherit (config.services.matrix-synapse) enable;
        };
      };
    };
  };
}
