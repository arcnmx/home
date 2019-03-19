{ config, pkgs, lib, ... }: with lib; {
  options = {
    home.profiles.vfio = mkEnableOption "VFIO";
  };

  config = mkIf config.home.profiles.vfio {
    home.packages = [
      #arc.ovmf-macboot
      #arc.qemu-headless
    ];
  };
}
