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
        aws_ssh_key.text = tf.import.common.output.refAttr "outputs.exports_sensitive.hosts.${networking.hostName}.aws_ssh_key.private_key_pem";
        ssh_key.text = resources.personal_ssh_key.refAttr "private_key_pem";
      } ++ map (ghUser: {
        "github_${ghUser}_ssh_key".text =
          resources."personal_github_ssh_key_${ghUser}".refAttr "private_key_pem";
      }) (attrNames userConfig.programs.git.gitHub.users));
      programs = mkIf tf.state.enable {
        ssh = {
          matchBlocks."git-codecommit.*.amazonaws.com" = {
            identitiesOnly = true;
            identityFile = userConfig.secrets.files.aws_ssh_key.path;
            user = tf.import.common.outputs.exports.import.hosts.${networking.hostName}.iam_ssh.ssh_public_key_id;
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
  deploy.imports = [ "common" ];
  deploy.tf = {
    resources = mkMerge (singleton {
      personal_ssh_key = {
        provider = "tls";
        type = "private_key";
        inputs = {
          algorithm = "ECDSA";
          ecdsa_curve = "P384";
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
