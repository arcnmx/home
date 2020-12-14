{ config, pkgs, lib, ... }: with lib; {
  options = {
    home.profiles.hw.x570am = mkEnableOption "GIGABYTE X570 Aorus Master";
  };

  config = mkIf config.home.profiles.hw.x570am {
    home.profiles.hw.ryzen = true;
  };
}
