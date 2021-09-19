{ config, pkgs, lib, ... }: with lib; {
  options = {
    home.profiles.host.cirno = mkEnableOption "hostname: cirno";
  };
  config = mkIf config.home.profiles.host.cirno {
    home.profiles.host.gensokyo = true;
    home.profiles.trusted = true;
    home.minimalSystem = true;
  };
}
