{ config, lib, ... }: with lib; let
  cfg = config.services.systemd2mqtt;
  enable = cfg.enable && cfg.mqtt.secretPassword != null;
in {
  options.services.systemd2mqtt = {
    mqtt.secretPassword = mkOption {
      type = types.nullOr types.str;
      default = null;
    };
  };
  config = {
    systemd.services.systemd2mqtt = mkIf enable {
      serviceConfig.EnvironmentFile = [
        config.secrets.files.systemd2mqtt.path
      ];
    };
    secrets.files.systemd2mqtt = mkIf enable {
      owner = cfg.user;
      text = ''
        MQTT_PASSWORD=${cfg.mqtt.secretPassword}
      '';
    };
  };
}
