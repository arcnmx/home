{ config, lib, ... }: with lib; {
  options = {
    home.profiles.hw.intel = mkEnableOption "Intel CPU";
  };

  config = mkIf config.home.profiles.hw.intel {
    hardware.cpu.intel.updateMicrocode = true;
  };
}
