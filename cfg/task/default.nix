{ meta, tf, config, lib, ... }: with lib; let
  inherit (tf) resources;
in {
  config = {
    home-manager.users.arc = { pkgs, nixosConfig, config, ... }: {
      imports = [ ./home.nix ];

      secrets.files = {
        taskserver-client.text = resources.taskserver_client_key.refAttr "private_key_pem";
        taskserver-cert.text = resources.taskserver_client_cert.refAttr "cert_pem";
        taskserver-creds.text = ''
          taskd.credentials=arc/arc/${tf.variables.TASKD_CREDS_ARC.ref}
        '';
      };
      programs.taskwarrior = mkIf tf.state.enable {
        taskd = {
          # NOTE: not sure why providing the LE CA is necessary here, but the client fails to verify otherwise
          authorityCertificate = mkIf meta.network.nodes.cirno.services.taskserver.enable (
            pkgs.writeText "taskd-ca.pem" (meta.deploy.targets.cirno.tf.acme.certs.${nixosConfig.networking.domains.taskserver.fqdn}.out.resource.importAttr "issuer_pem")
          );
          clientCertificate = config.secrets.files.taskserver-cert.path;
          clientKey = config.secrets.files.taskserver-client.path;
        };
        extraConfig = ''
          include ${config.secrets.files.taskserver-creds.path}
        '';
      };
    };
    deploy.tf = {
      inherit (import ./tf.nix {
        inherit (config) networking;
        inherit tf resources lib;
      }) resources;
      variables = {
        TASKD_CREDS_ARC.bitw.name = "taskd-arc";
      };
    };
  };
}
