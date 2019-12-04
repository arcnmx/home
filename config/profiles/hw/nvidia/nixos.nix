{ config, pkgs, lib, ... }: with lib; {
  options = {
    home.profiles.hw.nvidia = mkEnableOption "NVIDIA GPU";
    home.profileSettings.nvidia = {
      enableSoftwareI2c = mkEnableOption "DDC workaround for Pascal over HDMI";
    };
  };

  config = mkIf config.home.profiles.hw.nvidia {
    hardware.nvidia.modesetting.enable = true;
    hardware.opengl.extraPackages = with pkgs; [libvdpau-va-gl];
    # TODO: opencl_nvidia?
    services.xserver.videoDrivers = ["nvidiaBeta"];
    # xf86-video-nouveau?
    boot = {
      kernelModules = ["i2c-dev"];
      extraModprobeConfig = ''
        options nvidia NVreg_RegistryDwords=RMUseSwI2c=0x01;RMI2cSpeed=100
      '';
      #initrd.kernelModules = ["nvidia" "nvidia_modeset" "nvidia_uvm" "nvidia_drm"]; # is this necessary? for early kms?
    };
    services.xserver.deviceSection = ''
      Driver "nvidia"
      Option "NoLogo" "True"
      Option "Coolbits" "28"
    '' + optionalString config.home.profileSettings.nvidia.enableSoftwareI2c ''
      Option "RegistryDwords" "RMUseSwI2c=0x01;RMI2cSpeed=100"
    '';
  };
}
