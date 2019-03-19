{ config, pkgs, lib, ... }: with lib; {
  options = {
    home.profiles.hw.x370gpc = mkEnableOption "MSI X370 Gaming Pro Carbon";
  };

  config = mkIf config.home.profiles.hw.x370gpc {
    home.profiles.hw.ryzen = true;
  };
}
