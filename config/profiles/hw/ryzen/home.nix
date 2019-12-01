{ config, pkgs, lib, ... }: with lib; {
  options = {
    home.profiles.hw.ryzen = mkEnableOption "AMD Ryzen CPU";
  };

  config = mkIf config.home.profiles.hw.ryzen {
    #home.packages = [pkgs.zenstates];
  };
}
