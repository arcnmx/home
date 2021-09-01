{ tf, meta, config, pkgs, lib, ... }: with lib; let
  cfg = config.deploy.personal;
  inherit (tf) resources;
  inherit (config.deploy.tf.import) common;
  inherit (config.networking) domains;
  userType = { config, ... }: let
    userConfig = config;
  in {
    options.programs.git.gitHub.users = mkOption {
      type = types.attrsOf (types.submodule ({ name, config, ... }: {
        config.sshKeyPrivate = mkIf cfg.enable userConfig.secrets.files."github_${name}_ssh_key".path;
      }));
    };
    config = mkMerge [ {
      services.sshd.authorizedKeys = meta.deploy.personal.ssh.authorizedKeys;
    } (mkIf cfg.enable {
      programs = {
        ssh = {
          matchBlocks."git-codecommit.*.amazonaws.com" = mkIf config.home.profiles.trusted {
            identityFile = userConfig.secrets.files.iam_ssh_key.path;
            user = resources.personal_iam_ssh.getAttr "ssh_public_key_id";
          };
          extraConfig = ''
            IdentityFile ${userConfig.secrets.files.ssh_key.path}
          '';
        };
        taskwarrior.taskd = {
          # NOTE: not sure why providing the LE CA is necessary here, but the client fails to verify otherwise
          authorityCertificate = pkgs.writeText "taskd-ca.pem" (meta.deploy.targets.cirno.tf.acme.certs.${domains.taskserver.fqdn}.out.resource.importAttr "issuer_pem");
          clientCertificate = pkgs.writeText "taskd-client.pem" (resources.taskserver_client_cert.getAttr "cert_pem");
          clientKey = userConfig.secrets.files.taskserver-client.path;
        };
      };
      secrets.files = mkMerge (singleton {
        taskserver-client = mkIf userConfig.programs.taskwarrior.enable {
          text = resources.taskserver_client_key.refAttr "private_key_pem";
        };
        iam_ssh_key.text = resources.personal_aws_ssh_key.refAttr "private_key_pem";
        ssh_key.text = resources.personal_ssh_key.refAttr "private_key_pem";
      } ++ map (ghUser: {
        "github_${ghUser}_ssh_key".text =
          resources."personal_github_ssh_key_${ghUser}".refAttr "private_key_pem";
      }) (attrNames config.programs.git.gitHub.users));
    }) ];
  };
in {
  options.home-manager.users = mkOption {
    type = types.attrsOf (types.submoduleWith {
      modules = singleton userType;
    });
  };
  options.deploy.personal = {
    enable = mkEnableOption "deploy-personal";
    ssh.authorizedKeys = mkOption {
      type = types.listOf types.str;
      default = [ ];
    };
  };
  config.deploy = mkIf cfg.enable {
    personal.ssh.authorizedKeys = mkIf (tf.state.resources ? personal_ssh_key) [ (resources."personal_ssh_key".importAttr "public_key_openssh") ];
    tf = {
      imports = [ "common" ];
      resources = mkMerge (singleton {
        # TODO: deploy this key to gpg via ssh as part of switch??
        personal_ssh_key = {
          provider = "tls";
          type = "private_key";
          inputs = {
            algorithm = "ECDSA";
            ecdsa_curve = "P384";
          };
        };

        # TODO: deploy this key to gpg via ssh as part of switch??
        personal_aws_ssh_key = {
          provider = "tls";
          type = "private_key";
          inputs = {
            algorithm = "RSA";
            rsa_bits = 4096;
          };
        };

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
            key_algorithm = resources.taskserver_client_key.refAttr "algorithm";
            private_key_pem = resources.taskserver_client_key.refAttr "private_key_pem";

            subject = {
              common_name = "${config.networking.hostName}.${config.networking.domain}";
              organization = "arcnmx";
              organizational_unit = "taskserver";
            };
          };
        };
        taskserver_ca_key_ref.enable = true;
        taskserver_client_cert = {
          provider = "tls";
          type = "locally_signed_cert";
          inputs = {
            cert_request_pem = resources.taskserver_client_csr.refAttr "cert_request_pem";
            ca_key_algorithm = common.resources.taskserver_ca_key.importAttr "algorithm";
            ca_private_key_pem = resources.taskserver_ca_key_ref.refAttr "content";
            ca_cert_pem = common.resources.taskserver_ca.importAttr "cert_pem";

            allowed_uses = [
              "digital_signature"
              "client_auth"
            ];

            validity_period_hours = 365 * 4 * 24;
            early_renewal_hours = 365 * 24;
          };
        };
      } ++ map (ghUser: {
        # TODO: deploy this key to gpg via ssh as part of switch??
        "personal_github_ssh_key_${ghUser}" = {
          provider = "tls";
          type = "private_key";
          inputs = {
            algorithm = "ECDSA";
            ecdsa_curve = "P384";
          };
        };

        "personal_github_ssh_${ghUser}" = {
          provider = "github.github-${ghUser}";
          type = "user_ssh_key";
          inputs = {
            title = "${meta.deploy.idTag}/${config.networking.hostName}";
            key = resources."personal_github_ssh_key_${ghUser}".refAttr "public_key_openssh";
          };
        };
      }) (unique (concatMap (home: attrNames home.programs.git.gitHub.users) (attrValues config.home-manager.users))));
    };
  };
}
