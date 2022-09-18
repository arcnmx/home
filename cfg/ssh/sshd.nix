{ config, lib, ... }: with lib; let
  cfg = config.services.openssh;
in {
  options.services.openssh = {
    port = mkOption {
      type = types.port;
      default = 22; # TODO: start using a different port for personal and server machines? way too much spam otherwise...
    };
  };
  config.services.openssh = {
    enable = true;
    ports = [ cfg.port ];
    startWhenNeeded = mkDefault false;
    allowSFTP = true;
    gatewayPorts = "yes";
    kbdInteractiveAuthentication = false;
    passwordAuthentication = mkDefault false;
    useDns = false;
    extraConfig = ''
      MaxSessions 100
      AllowAgentForwarding yes
      AllowTcpForwarding yes
      PrintMotd no
      PermitUserEnvironment yes
      Compression yes
      PermitTunnel yes
    '';
  };
}
