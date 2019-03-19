{ config, pkgs, lib, ... }: with lib; {
  options = {
    home.profiles.hw.z170xpsli = mkEnableOption "GIGABYTE Z170 XP SLI";
  };

  config = mkIf config.home.profiles.hw.z170xpsli {
    home.profiles.hw.intel = true;
  };
}
