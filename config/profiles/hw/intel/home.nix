{ config, pkgs, lib, ... }: with lib; {
  options = {
    home.profiles.hw.intel = mkEnableOption "Intel CPU";
  };

  config = mkIf config.home.profiles.hw.intel {
    home.packages = [pkgs.i7z];
  };
}
