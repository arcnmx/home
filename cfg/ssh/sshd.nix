{ config, lib, ... }: with lib; let
  cfg = config.services.openssh;
  data = import ./data.nix;
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
    settings = {
      KbdInteractiveAuthentication = false;
      PasswordAuthentication = mkDefault false;
      UseDns = false;
      MaxSessions = 100;
      AllowAgentForwarding = true;
      AllowTcpForwarding = true;
      GatewayPorts = "yes";
      #PermitUserEnvironment = true;
      AcceptEnv = toString data.SendEnv;
      Compression = true;
      PermitTunnel = true;
    };
  };
  config.systemd.services = {
    "sshd@" = mkIf (cfg.enable && cfg.startWhenNeeded) {
      restartIfChanged = false;
    };
    "sshd" = mkIf (cfg.enable && !cfg.startWhenNeeded) {
      restartIfChanged = false;
    };
  };
}
