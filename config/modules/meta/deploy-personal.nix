{ config, lib, ... }: with lib; let
  cfg = config.deploy.personal;
  inherit (config.deploy.tf) resources;
  personalNodes = filter (node: node.deploy.personal.enable) (attrValues config.network.nodes);
in {
  options.deploy.personal = {
    ssh.authorizedKeys = mkOption {
      type = types.listOf types.str;
      default = [ ];
    };
  };
  config.deploy.personal = {
    ssh.authorizedKeys = mkMerge (map (node: node.deploy.personal.ssh.authorizedKeys) personalNodes);
  };
}
