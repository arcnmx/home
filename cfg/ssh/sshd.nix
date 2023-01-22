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
    settings = {
      KbdInteractiveAuthentication = false;
      PasswordAuthentication = mkDefault false;
      UseDns = false;
      MaxSessions = 100;
      AllowAgentForwarding = true;
      AllowTcpForwarding = true;
      PermitUserEnvironment = true;
      Compression = true;
      PermitTunnel = true;
    };
  };
}
