{ config, pkgs, lib, ... }: with lib; {
  options.home = {
    profiles.host.aya = mkEnableOption "hostname: aya";
  };

  config = mkIf config.home.profiles.host.aya {
    home.profiles.hw.pinecube = true;
    home.profiles.trusted = true;
    home.minimalSystem = true;
  };
}
