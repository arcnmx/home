{ config, pkgs, lib, ... }: with lib; {
  options = {
    home.profiles.hw.nvidia = mkEnableOption "NVIDIA GPU";
  };

  config = mkIf config.home.profiles.hw.nvidia {
    programs.mpv = {
      extraConfig = {
        hwdec = "cuda";

        profile = "gpu-hq";
      };
    };
  };
}
