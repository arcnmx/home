{ config, lib, ... }: with lib; let
  cfg = config.qga;
in {
  options.qga = {
    enable = mkEnableOption "QGA";
    path = mkOption {
      type = types.path;
      default = config.state.runtimePath + "/qga";
    };
    bus = mkOption {
      type = types.str;
    };
    port = mkOption {
      type = types.int;
      default = 0;
    };
  };
  config = mkIf cfg.enable {
    chardevs.qga0.settings = {
      backend = "socket";
      id = "qga0sock";
      inherit (cfg) path;
      server = true;
      wait = false;
    };
    devices.qga0 = {
      cli.dependsOn = [ config.chardevs.qga0.id cfg.bus ];
      settings = {
        driver = "virtserialport";
        name = "org.qemu.guest_agent.0";
        chardev = config.chardevs.qga0.id;
        bus = "${cfg.bus}.${toString cfg.port}";
      };
    };
  };
}
