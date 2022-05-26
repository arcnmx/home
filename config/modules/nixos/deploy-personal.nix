{ tf, meta, config, pkgs, lib, ... }: with lib; let
  cfg = config.deploy.personal;
  inherit (tf) resources variables;
  inherit (config.deploy.tf.import) common;
  inherit (config.networking) domains;
  userType = { config, ... }: let
    userConfig = config;
    inherit (config.lib.file) mkOutOfStoreSymlink;
  in {
    options.programs.git.gitHub.users = mkOption {
      type = types.attrsOf (types.submodule ({ name, config, ... }: {
        config.sshKeyPrivate = mkIf (cfg.enable && tf.state.enable) userConfig.secrets.files."github_${name}_ssh_key".path;
      }));
    };
    config = mkMerge [ {
      services.sshd.authorizedKeys = meta.deploy.personal.ssh.authorizedKeys;
    } (mkIf (cfg.enable && tf.state.enable) {
      programs = {
        ssh = {
          matchBlocks."git-codecommit.*.amazonaws.com" = mkIf (userConfig.secrets.files ? iam_ssh_key) {
            identitiesOnly = true;
            identityFile = userConfig.secrets.files.iam_ssh_key.path;
            user = resources.personal_iam_ssh.getAttr "ssh_public_key_id";
            extraOptions = {
              HostkeyAlgorithms = "+ssh-rsa";
              PubkeyAcceptedAlgorithms = "+ssh-rsa";
            };
          };
          extraConfig = ''
            IdentityFile ${userConfig.secrets.files.ssh_key.path}
          '';
        };
        taskwarrior = {
          taskd = {
            # NOTE: not sure why providing the LE CA is necessary here, but the client fails to verify otherwise
            authorityCertificate = mkIf meta.network.nodes.cirno.services.taskserver.enable (
              pkgs.writeText "taskd-ca.pem" (meta.deploy.targets.cirno.tf.acme.certs.${domains.taskserver.fqdn}.out.resource.importAttr "issuer_pem")
            );
            clientCertificate = pkgs.writeText "taskd-client.pem" (resources.taskserver_client_cert.getAttr "cert_pem");
            clientKey = userConfig.secrets.files.taskserver-client.path;
          };
          extraConfig = ''
            include ${userConfig.secrets.files.taskserver-creds.path}
          '';
        };
      };
      services = {
        mpd = {
          extraConfig = ''
            password "${resources.mpd_password.refAttr "result"}@read,add,control"
            password "${resources.mpd_password_admin.refAttr "result"}@read,add,control,admin"
          '';
          configPath = userConfig.secrets.files.mpd-config.path;
        };
      };
      xdg.configFile."cargo/config" = {
        source = mkOutOfStoreSymlink userConfig.secrets.files.cargo-config.path;
      };
      secrets.files = mkMerge (singleton {
        taskserver-client = mkIf userConfig.programs.taskwarrior.enable {
          text = resources.taskserver_client_key.refAttr "private_key_pem";
        };
        taskserver-creds = mkIf userConfig.programs.taskwarrior.enable {
          text = ''
            taskd.credentials=arc/arc/${variables.TASKD_CREDS_ARC.ref}
          '';
        };
        iam_ssh_key = mkIf (meta.deploy.targets ? archive.tf.resources.personal_iam_user) {
          text = resources.personal_aws_ssh_key.refAttr "private_key_pem";
        };
        ssh_key.text = resources.personal_ssh_key.refAttr "private_key_pem";
        cargo-config = {
          text = ''
            [registry]
            token = "${variables.CRATES_TOKEN_ARC.ref}"
          '';
        };
        mpd-config = mkIf userConfig.services.mpd.enable {
          text = userConfig.services.mpd.configText;
        };
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
          enable = resources.personal_iam_ssh.enable;
          provider = "tls";
          type = "private_key";
          inputs = {
            algorithm = "RSA";
            rsa_bits = 4096;
          };
        };
        personal_iam_ssh = {
          enable = meta.deploy.targets ? archive.tf.resources.personal_iam_user;
          provider = "aws";
          type = "iam_user_ssh_key";
          inputs = {
            username = meta.deploy.targets.archive.tf.resources.personal_iam_user.importAttr "name";
            encoding = "SSH";
            public_key = resources.personal_aws_ssh_key.refAttr "public_key_openssh";
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

        mpd_password = {
          enable = any (u: u.services.mpd.enable) (attrValues config.home-manager.users);
          provider = "random";
          type = "password";
          inputs = {
            length = 12;
            special = false;
          };
        };
        mpd_password_admin = {
          enable = any (u: u.services.mpd.enable) (attrValues config.home-manager.users);
          provider = "random";
          type = "password";
          inputs = {
            length = 16;
            special = false;
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
      variables = {
        TASKD_CREDS_ARC.bitw.name = "taskd-arc";
        CRATES_TOKEN_ARC.bitw.name = "crates-arcnmx";
      };
    };
  };
}
