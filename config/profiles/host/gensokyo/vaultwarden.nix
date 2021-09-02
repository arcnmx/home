{ tf, config, pkgs, lib, ... }: with lib; let
  inherit (config.networking) domains bindings;
in {
  config = mkIf config.home.profiles.host.gensokyo {
    deploy.tf = {
      resources = {
        vaultwarden_token = mkIf config.services.vaultwarden.enable {
          provider = "random";
          type = "password";
          inputs = {
            length = 64;
          };
        };
      };
    };
    services = {
      vaultwarden = {
        domain = domains.bitwarden;
        bindings = {
          rocket = bindings.vaultwarden-private;
          websocket = bindings.vaultwarden-private-websocket;
        };
        dbBackend = mkIf config.services.postgresql.enable "postgresql";
        config = {
          #adminToken = tf.resources.vaultwarden_token.getAttr "result"; # NOTE: keep unset unless admin page is needed
          webVaultEnabled = mkDefault true;
          signupsAllowed = mkDefault false;
          websocketEnabled = mkDefault true;
          rocketEnv = mkDefault "production";
          dataFolder = "/var/lib/bitwarden_rs";
          databaseUrl = mkMerge [
            (mkDefault "${config.services.vaultwarden.config.dataFolder}/db.sqlite3")
            (mkIf config.services.postgresql.enable "postgresql://bitwarden_rs@/bitwarden_rs")
          ];
        };
      };
      postgresql = mkIf (config.services.vaultwarden.enable && config.services.vaultwarden.dbBackend == "postgresql") {
        ensureDatabases = singleton "bitwarden_rs";
        ensureUsers = singleton {
          name = "bitwarden_rs";
          ensurePermissions = {
            "DATABASE bitwarden_rs" = "ALL PRIVILEGES";
          };
        };
      };
      nginx.virtualHosts.${domains.bitwarden.key} = mkIf config.services.vaultwarden.enable {
        locations = {
          "/" = {
            proxyPassConnection.binding = bindings.vaultwarden-private;
          };
          "/notifications/hub" = {
            proxyPassConnection.binding = bindings.vaultwarden-private-websocket;
            proxyWebsockets = true;
          };
          "/notifications/hub/negotiate" = {
            proxyPassConnection.binding = bindings.vaultwarden-private;
          };
          "/admin" = {
            proxyPassConnection = {
              enable = config.services.vaultwarden.config ? adminToken;
              binding = bindings.vaultwarden-private;
            };
          };
        };
      };
    };
    users.users.vaultwarden = mkIf config.services.vaultwarden.enable {
      name = "bitwarden_rs";
    };
    systemd.services.vaultwarden = mkIf (config.services.vaultwarden.enable && config.services.vaultwarden.dbBackend == "postgresql") {
      requires = [ "postgresql.service" ];
      after = [ "postgresql.service" ];
    };
    system.mutableState.services.vaultwarden = {
      name = "bitwarden_rs";
      owner = "bitwarden_rs";
      databases.postgresql = mkIf (config.services.vaultwarden.dbBackend == "postgresql" && config.services.postgresql.enable) (mkForce [ "bitwarden_rs" ]);
    };

    networking = {
      bindings = {
        vaultwarden-private = { };
        vaultwarden-private-websocket = { };
      };
      domains = {
        bitwarden = {
          inherit (config.services.vaultwarden) enable;
          sslOnly = true;
        };
      };
    };
  };
}
