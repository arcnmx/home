{ config, pkgs, lib, ... }: with lib; {
  options = {
    home.profiles.host.mystia = mkEnableOption "hostname: mystia";
  };
}
