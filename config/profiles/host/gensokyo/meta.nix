{ lib, config, ... }: with lib; let
  target = config.deploy.targets.common;
  inherit (target) tf;
  inherit (tf) acme;
  inherit (config.deploy) domains;
  bindLocal = "localhost";
  bindAny = "0.0.0.0";
in {
  config.deploy = {
    domains = mkMerge [ {
      taskserver = {
        public = with acme.certs.${domains.taskserver.public.fqdn}; {
          pem = out.importFullchainPem;
          keyName = name;
        };
        ca.pem = tf.resources.taskserver_ca.importAttr "cert_pem";
      };
      bitwarden_rs = {
        public = with acme.certs.${domains.bitwarden_rs.public.fqdn}; {
          pem = out.importFullchainPem;
          keyName = name;
        };
      };
      prosody = {
        vanity = with acme.certs.${domains.prosody.vanity.fqdn}; {
          pem = out.importFullchainPem;
          keyName = name;
        };
      };
      matrix-synapse = {
        vanity = with acme.certs.${domains.matrix-synapse.vanity.fqdn}; {
          pem = out.importFullchainPem;
          keyName = name;
        };
        public = with acme.certs.${domains.matrix-synapse.public.fqdn}; {
          pem = out.importFullchainPem;
          keyName = name;
        };
        federation = with acme.certs.${domains.matrix-synapse.federation.fqdn}; {
          pem = out.importFullchainPem;
          keyName = name;
        };
      };
      misc.mystia = with acme.certs.${domains.misc.mystia.fqdn}; {
        pem = out.importFullchainPem;
        keyName = name;
      };
    } {
      # domain defaults
      taskserver = {
        public = {
          bind = mkDefault bindAny; # "*" "::"
          port = mkDefault 53589;
          # TODO: default pki = null;
        };
        ca = { };
      };
      prosody = {
        vanity = { bind = mkDefault null; };
        public = { port = mkDefault 5222; bind = mkDefault bindAny; };
        federation = { port = mkDefault 5269; bind = mkDefault bindAny; };
      };
      matrix-synapse = {
        private = { protocol = mkDefault "http"; port = mkDefault 0; bind = mkDefault bindLocal; };
        private-federation = { protocol = mkDefault "http"; port = mkDefault 0; bind = mkDefault bindLocal; };
        public = { protocol = mkDefault "https"; bind = mkDefault bindAny; };
        vanity = { protocol = mkDefault "https"; bind = mkDefault bindAny; };
        federation = { protocol = mkDefault "https"; bind = mkDefault bindAny; port = mkDefault 8448; };
      };
      bitwarden_rs = {
        private = { protocol = mkDefault "http"; port = mkDefault 0; bind = mkDefault bindLocal; };
        private-websocket = { protocol = mkDefault "http"; port = mkDefault 0; bind = mkDefault bindLocal; };
        public = { protocol = mkDefault "https"; bind = mkDefault bindAny; };
      };
      misc = { };
    } ];
    targets.common.tf = {
      acme = {
        account = {
          register = true;
          accountKeyPem = tf.resources.acme_key.refAttr "private_key_pem";
        };
        certs = with domains; listToAttrs (map (domain: nameValuePair domain {
          dnsNames = singleton domain;
        }) [
          taskserver.public.fqdn
          bitwarden_rs.public.fqdn
          prosody.vanity.fqdn
          matrix-synapse.vanity.fqdn
          matrix-synapse.public.fqdn
          matrix-synapse.federation.fqdn
          misc.mystia.fqdn
        ]);
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
        taskserver_ca_key = {
          provider = "tls";
          type = "private_key";
          inputs = {
            algorithm = "RSA";
            rsa_bits = 2048;
          };
        };
        taskserver_ca = {
          provider = "tls";
          type = "self_signed_cert";
          inputs = {
            key_algorithm = tf.resources.taskserver_ca_key.refAttr "algorithm";
            private_key_pem = tf.resources.taskserver_ca_key.refAttr "private_key_pem";
            is_ca_certificate = true;
            subject = {
              common_name = domains.taskserver.public.fqdn;
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
        };
      };
    };
  };
}
