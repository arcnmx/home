{ meta, tf, config, lib, ... }: with lib; let
  inherit (tf) resources;
  inherit (config.home-manager.users) arc;
  inherit (config) networking;
  githubUsers = attrNames arc.programs.git.gitHub.users;
in {
  home-manager.users.arc = { config, ... }: let
    userConfig = config;
  in {
    options.programs.git.gitHub.users = mkOption {
      type = types.attrsOf (types.submodule ({ name, config, ... }: {
        config.sshKeyPrivate = mkIf tf.state.enable userConfig.secrets.files."github_${name}_ssh_key".path;
      }));
    };
    config = {
      secrets.files = mkMerge (singleton {
        iam_ssh_key.text = resources.personal_aws_ssh_key.refAttr "private_key_pem";
        ssh_key.text = resources.personal_ssh_key.refAttr "private_key_pem";
      } ++ map (ghUser: {
        "github_${ghUser}_ssh_key".text =
          resources."personal_github_ssh_key_${ghUser}".refAttr "private_key_pem";
      }) (attrNames userConfig.programs.git.gitHub.users));
      programs = mkIf tf.state.enable {
        ssh = {
          matchBlocks."git-codecommit.*.amazonaws.com" = {
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
      };
    };
  };
  deploy.personal.ssh.authorizedKeys = mkIf (tf.state.resources ? personal_ssh_key) [ (resources.personal_ssh_key.importAttr "public_key_openssh") ];
  deploy.tf = {
    imports = [ "archive" ];
    resources = mkMerge (singleton {
      personal_ssh_key = {
        provider = "tls";
        type = "private_key";
        inputs = {
          algorithm = "ECDSA";
          ecdsa_curve = "P384";
        };
      };
      personal_aws_ssh_key = {
        provider = "tls";
        type = "private_key";
        inputs = {
          algorithm = "RSA";
          rsa_bits = 4096;
        };
      };
      personal_iam_ssh = {
        provider = "aws";
        type = "iam_user_ssh_key";
        inputs = {
          username = tf.import.archive.resources.personal_iam_user.importAttr "name";
          encoding = "SSH";
          public_key = resources.personal_aws_ssh_key.refAttr "public_key_openssh";
        };
      };
    } ++ map (ghUser: {
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
    }) githubUsers);
  };
}
