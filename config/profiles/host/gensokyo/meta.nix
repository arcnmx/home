{ lib, config, ... }: with lib; let
  target = config.deploy.targets.common;
  inherit (target) tf;
in {
  options = {
    deploy.targets = let
      tfModule = { config, ... }: {
        config = {
          acme = {
            account = {
              accountKeyPem = mkDefault (config.resources.acme_key_ref.refAttr "content");
              emailAddress = mkDefault tf.acme.account.emailAddress;
            };
          };
          resources = {
            acme_key_ref = {
              enable = mkDefault config.acme.enable;
              provider = "local";
              type = "file";
              dataSource = true;
              inputs.filename = tf.resources.acme_key_file.importAttr "filename";
            };
            taskserver_ca_key_ref = {
              enable = mkDefault false;
              provider = "local";
              type = "file";
              dataSource = true;
              inputs.filename = tf.resources.taskserver_ca_key_file.importAttr "filename";
            };
          };
        };
      };
      targetModule = { ... }: {
        options.tf = mkOption {
          type = types.submodule tfModule;
        };
      };
    in mkOption {
      type = types.attrsOf (types.submodule targetModule);
    };
  };
  config.deploy = {
    archive.borg.retiredArchives = [
      /*"taskserver"
      #"gitolite"
      #"bitlbee"
      "bitwarden_rs" # "bitwarden_rs-postgresql"
      "matrix-synapse" # "matrix-synapse-postgresql"
      "prosody" # "prosody-postgresql"
      "mautrix-googlechat" "mautrix-whatsapp" "mx-puppet-discord"*/
      "mautrix-hangouts"
    ];
    targets.common.tf = {
      acme = {
        account = {
          register = true;
          accountKeyPem = tf.resources.acme_key.refAttr "private_key_pem";
        };
      };
      dns.records = mapAttrs (host: address: {
        inherit (config.network.tailscale) zone;
        domain = "${host}.local";
        a = {
          inherit address;
        };
      }) {
        diapergenie = "10.1.1.1";
        gensokyo = "10.1.1.4";
        komeijinet = "10.1.1.5";
      };
      resources = {
        acme_key = {
          provider = "tls";
          type = "private_key";
          inputs = {
            algorithm = "ECDSA";
            ecdsa_curve = "P384";
          };
        };
        acme_key_file = {
          provider = "local";
          type = "sensitive_file";
          inputs = {
            content = tf.resources.acme_key.refAttr "private_key_pem";
            filename = toString (tf.terraform.dataDir + "/acme.priv.pem");
            file_permission = "0600";
          };
        };
        taskserver_ca_key = {
          provider = "tls";
          type = "private_key";
          inputs = {
            algorithm = "RSA";
            rsa_bits = 2048;
          };
        };
        taskserver_ca_key_file = {
          provider = "local";
          type = "sensitive_file";
          inputs = {
            content = tf.resources.taskserver_ca_key.refAttr "private_key_pem";
            filename = toString (tf.terraform.dataDir + "/taskserver_ca.priv.pem");
            file_permission = "0600";
          };
        };
        taskserver_ca = {
          provider = "tls";
          type = "self_signed_cert";
          inputs = {
            private_key_pem = tf.resources.taskserver_ca_key.refAttr "private_key_pem";
            is_ca_certificate = true;
            subject = {
              common_name = "taskserver";
              organization = "arcnmx";
              organizational_unit = "taskserver";
            };
            allowed_uses = [
              "digital_signature"
              "cert_signing"
            ];
            validity_period_hours = 365 * 4 * 24;
            early_renewal_hours = 365 * 24;
          };
          lifecycle.ignoreChanges = singleton "subject";
        };
      };
    };
  };
}
