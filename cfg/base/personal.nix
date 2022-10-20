{ config, lib, ... }: with lib; {
  options.deploy.personal = with types; {
    enable = mkEnableOption "deploy-personal";
    ssh.authorizedKeys = mkOption {
      type = listOf str;
      default = [ ];
    };
  };
}
