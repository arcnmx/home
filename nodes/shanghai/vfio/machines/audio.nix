{ nixosConfig, config, lib, ... }: with lib; {
  config = {
    audio = {
      enable = mkDefault true;
      pulseaudio = {
        server = "/run/user/${toString nixosConfig.users.users.${config.state.owner}.uid}/pulse/native";
        "out.fixed-settings" = false;
        "out.mixing-engine" = false;
      };
    };
  };
}
