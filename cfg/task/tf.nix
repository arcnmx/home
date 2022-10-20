{ resources, common, networking, lib }: with lib; {
  resources = {
    taskserver_client_key = {
      provider = "tls";
      type = "private_key";
      inputs = {
        algorithm = "RSA";
        rsa_bits = 2048;
      };
    };

    taskserver_client_csr = {
      provider = "tls";
      type = "cert_request";
      inputs = {
        private_key_pem = resources.taskserver_client_key.refAttr "private_key_pem";

        subject = {
          common_name = "${networking.hostName}.${networking.domain}";
          organization = "arcnmx";
          organizational_unit = "taskserver";
        };
      };
      lifecycle.ignoreChanges = singleton "subject";
    };

    taskserver_client_cert = {
      provider = "tls";
      type = "locally_signed_cert";
      inputs = {
        cert_request_pem = resources.taskserver_client_csr.refAttr "cert_request_pem";
        ca_private_key_pem = resources.taskserver_ca_key_ref.refAttr "content";
        ca_cert_pem = common.tf.resources.taskserver_ca.importAttr "cert_pem";

        allowed_uses = [
          "digital_signature"
          "client_auth"
        ];

        validity_period_hours = 365 * 4 * 24;
        early_renewal_hours = 365 * 24;
      };
    };
  };
}
