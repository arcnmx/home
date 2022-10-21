{ config, lib, ... }: with lib; let
  inherit (config.deploy.targets) common archive;
  inherit (common.tf) resources;
  cfg = config.deploy.personal;
  meta = config;
  enabledHosts = filterAttrs (_: h: h.enable) cfg.hosts;
  hostType = { config, name, ... }: {
    options = with types; {
      enable = mkEnableOption "personal host" // {
        default = true;
      };
    };
  };
  hostResources = hostName: hostConfig: {
    "${hostName}_aws_ssh_key" = {
      provider = "tls";
      type = "private_key";
      inputs = {
        algorithm = "RSA";
        rsa_bits = 4096;
      };
    };
    "${hostName}_iam_ssh" = {
      provider = "aws";
      type = "iam_user_ssh_key";
      inputs = {
        username = resources.personal_iam_user.refAttr "name";
        encoding = "SSH";
        public_key = resources."${hostName}_aws_ssh_key".refAttr "public_key_openssh";
      };
    };
  };
  mapOutputs = hostName: mapAttrs (resource: attrs: genAttrs attrs (attr:
    resources."${optionalString (hostName != null) "${hostName}_"}${resource}".refAttr attr
  ));
  hostOutputs = hostConfig: {
    iam_ssh = [ "ssh_public_key_id" ];
  };
  hostSensitiveOutputs = hostConfig: {
    aws_ssh_key = [ "private_key_pem" ];
  };
in {
  options.deploy.personal = with types; {
    hosts = mkOption {
      type = attrsOf (submodule hostType);
      default = { };
    };
  };
  config = {
    deploy.targets.common.tf = {
      resources = mkMerge (singleton {
        personal_iam_user = {
          provider = "aws";
          type = "iam_user";
          inputs = {
            name = "home";
            path = "/${config.deploy.idTag}/";
          };
        };
        mpd_password = {
          provider = "random";
          type = "password";
          inputs = {
            length = 12;
            special = false;
          };
        };
      } ++ mapAttrsToList hostResources enabledHosts);
      outputs = {
        exports = {
          value = mapOutputs null {
            taskserver_ca = [ "cert_pem" ];
            personal_iam_user = [ "name" ];
          } // {
            hosts = mapAttrs (hostName: hostConfig: mapOutputs hostName (hostOutputs hostConfig)) enabledHosts;
          };
        };
        exports_sensitive = {
          sensitive = true;
          value = mapOutputs null {
            mpd_password = [ "result" ];
            taskserver_ca_key = [ "private_key_pem" ];
          } // {
            hosts = mapAttrs (hostName: hostConfig: mapOutputs hostName (hostSensitiveOutputs hostConfig)) enabledHosts;
          };
        };
      };
    };
  };
}
