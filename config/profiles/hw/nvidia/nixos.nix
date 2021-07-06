{ config, pkgs, lib, ... }: with lib; {
  options = {
    home.profiles.hw.nvidia = mkEnableOption "NVIDIA GPU";
    home.profileSettings.nvidia = {
      enableSoftwareI2c = mkEnableOption "DDC workaround for Pascal over HDMI";
      patch = mkEnableOption "nvidia-patch" // { default = true; };
    };
  };

  config = mkIf config.home.profiles.hw.nvidia {
    hardware.nvidia = {
      modesetting.enable = true;
      package = let
        inherit (config.boot.kernelPackages.nvidiaPackages) stable beta;
        package = if versionAtLeast beta.version stable.version then beta else stable;
      in if config.home.profileSettings.nvidia.patch
        then pkgs.nvidia-patch.override { nvidia_x11 = package; }
        else package;
    };
    hardware.display.nvidia.enable = true;
    hardware.opengl.extraPackages = with pkgs; [libvdpau-va-gl];
    # TODO: opencl_nvidia?
    services.xserver.videoDrivers = ["nvidia"];
    # xf86-video-nouveau?
    boot = {
      kernelModules = ["i2c-dev"];
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
