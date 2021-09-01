{ config, pkgs, lib, ... }: with lib; {
  options = {
    home.profiles.host.cirno = mkEnableOption "hostname: cirno";
  };
}
