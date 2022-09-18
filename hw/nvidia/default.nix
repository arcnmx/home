{ config, pkgs, lib, ... }: with lib; {
  key = "NVIDIA GPU";

  options = {
    home.profileSettings.nvidia = {
      enableSoftwareI2c = mkEnableOption "DDC workaround for Pascal over HDMI";
      patch = mkEnableOption "nvidia-patch" // { default = true; };
      dynamicBinding = mkEnableOption "dynamic gpu unbinding";
    };
  };

  config = {
    home-manager.users.arc = { ... }: {
      imports = [ ./home.nix ];
    };

    hardware.nvidia = {
      modesetting.enable = !config.home.profileSettings.nvidia.dynamicBinding;
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
      kernelPackages = mkIf (versionOlder pkgs.linuxPackages.nvidiaPackages.stable.version "515.65.02") (mkForce pkgs.linuxPackages_5_19); # TODO: 6.0-rc is currently broken :<
      kernelModules = ["i2c-dev"];
      modprobe.modules = mkIf config.home.profileSettings.nvidia.dynamicBinding {
        nvidia_drm.blacklist = true;
      };
    };
    services.xserver.deviceSection = ''
      Driver "nvidia"
      Option "NoLogo" "True"
      Option "Coolbits" "28"
    '' + optionalString config.home.profileSettings.nvidia.enableSoftwareI2c ''
      Option "RegistryDwords" "RMUseSwI2c=0x01;RMI2cSpeed=100"
    '';
    services.xserver.displayManager.lightdm.extraConfig = mkIf config.home.profileSettings.nvidia.dynamicBinding ''
      logind-check-graphical=false
    '';
  };
}
