{ config, pkgs, lib, ... }: with lib; {
  options = {
    home.profiles.hw.nvidia = mkEnableOption "NVIDIA GPU";
  };

  config = mkIf config.home.profiles.hw.nvidia {
    services.picom = {
      backend = "xrender";
      extraOptions = ''
        unredir-if-possible = true;
      '';
    };
    programs.mpv = {
      config = {
        hwdec = "cuda";

        profile = "gpu-hq";
      };
    };
  };
}
