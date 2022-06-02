{ lib, ... }: with lib; {
  services.openssh = {
    enable = true;
    ports = mkDefault [22]; # TODO: start using a different port for personal and server machines? way too much spam otherwise...
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
