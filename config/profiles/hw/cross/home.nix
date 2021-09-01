{ config, pkgs, lib, ... }: with lib; {
  options = {
    home.profiles.hw.cross = mkEnableOption "Cross";
  };
}
