{ config, lib, ... }: with lib; let
  inherit (config.deploy.targets) common;
  inherit (common) tf;
in {
  deploy.targets.common.tf = {
    outputs.github-access = {
      sensitive = true;
      value = tf.variables.github-access.ref;
    };
    variables.github-access = {
      bitw.name = "github-public-access";
    };
  };
}
