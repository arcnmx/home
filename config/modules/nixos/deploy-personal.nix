{ tf, meta, config, lib, ... }: with lib; let
  cfg = config.deploy.personal;
  inherit (tf) resources;
in {
  options.deploy.personal = {
    enable = mkEnableOption "deploy-personal";
    ssh.authorizedKeys = mkOption {
      type = types.listOf types.str;
      default = [ ];
    };
  };
  config.deploy = mkIf cfg.enable {
    personal.ssh.authorizedKeys = mkIf (tf.state.resources ? personal_ssh_key) [ (resources."personal_ssh_key".importAttr "public_key_openssh") ];
    tf = mkMerge (singleton {
      resources = {
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
      };
    } ++ map (ghUser: {
      resources = {
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
            title = "${config.networking.hostName} deploy key";
            key = resources."personal_github_ssh_key_${ghUser}".refAttr "public_key_openssh";
          };
        };
      };
    }) (unique (concatMap (home: attrNames home.programs.git.gitHub.users) (attrValues config.home-manager.users))));
  };
  options.home-manager.users = mkOption {
    type = types.attrsOf (types.submodule ({ config, ... }: let
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
        programs.ssh = {
          matchBlocks.codecommit.identityFile =
            userConfig.secrets.files.iam_ssh_key.path;
          extraConfig = ''
            IdentityFile ${userConfig.secrets.files.ssh_key.path}
          '';
        };
        secrets.files = mkMerge (singleton {
          iam_ssh_key.text = resources."personal_aws_ssh_key".refAttr "private_key_pem";
          ssh_key.text = resources."personal_ssh_key".refAttr "private_key_pem";
        } ++ map (ghUser: {
          "github_${ghUser}_ssh_key".text =
            resources."personal_github_ssh_key_${ghUser}".refAttr "private_key_pem";
        }) (attrNames config.programs.git.gitHub.users));
      }) ];
    }));
  };
}
