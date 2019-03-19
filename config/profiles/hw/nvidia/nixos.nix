{ config, pkgs, lib, ... }: with lib; {
  options = {
    home.profiles.hw.nvidia = mkEnableOption "NVIDIA GPU";
  };

  config = mkIf config.home.profiles.hw.nvidia {
    hardware.nvidia.modesetting.enable = true;
    hardware.opengl.extraPackages = with pkgs; [libvdpau-va-gl opencl_nvidia];
    services.xserver.videoDrivers = ["nvidiaBeta"];
    # xf86-video-nouveau?
    boot.kernelModules = ["i2c-dev"];
    boot.extraModprobeConfig = ''
      options nvidia NVreg_RegistryDwords=RMUseSwI2c=0x01;RMI2cSpeed=100
    '';
    boot.initrd.kernelModules = ["nvidia" "nvidia_modeset" "nvidia_uvm" "nvidia_drm"]; # is this necessary? for early kms?
    services.xserver.deviceSection = ''
      Driver "nvidia"
      Option "NoLogo" "True"
      Option "Coolbits" "4"
      Option "RegistryDwords" "RMUseSwI2c=0x01;RMI2cSpeed=100"
    '';
  };
}
