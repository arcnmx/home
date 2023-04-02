{ inputs, config, pkgs, lib, ... }: with lib; let
  cfg = config.hardware.nvidia;
  openglPackages = pkgs: with pkgs; mkMerge [
    # TODO: opencl_nvidia?
  ];
  isNvidiaDriver = cfg.driver == "nvidia" || cfg.driver == "nvidia-open";
  inherit (config.boot.kernelPackages.nvidiaPackages) stable beta;
in {
  key = "NVIDIA GPU";
  imports = [ inputs.nvidia-patch.nixosModules.default ];

  options = with types; {
    hardware.nvidia = {
      driver = mkOption {
        type = enum [ "nvidia" "nvidia-open" "nouveau" "nvk" ];
        default = "nvidia";
      };
      enableSoftwareI2c = mkEnableOption "DDC workaround for Pascal over HDMI";
      dynamicBinding = mkEnableOption "dynamic gpu unbinding";
    };
  };

  config = {
    home-manager.users.arc = { ... }: {
      imports = [ ./home.nix ];
    };
    hardware = {
      nvidia = {
        patch = {
          enable = mkIf (cfg.driver != "nvidia") (mkDefault false);
          softEnable = mkDefault true;
          nvidiaPackage = if versionAtLeast beta.version stable.version then beta else stable;
        };
        open = cfg.driver == "nvidia-open";
        modesetting.enable = !cfg.dynamicBinding;
        package = mkDefault cfg.patch.nvidiaPackage;
      };
      display.nvidia.enable = mkIf isNvidiaDriver true;
      opengl = {
        mesa.enable = !isNvidiaDriver;
        extraPackages = openglPackages pkgs;
        extraPackages32 = openglPackages pkgs.driversi686Linux;
      };
    };
    services.xserver.videoDrivers = [ cfg.driver ];
    boot = {
      kernelModules = [ "i2c-dev" ];
      modprobe.modules = mkIf (cfg.dynamicBinding && isNvidiaDriver)  {
        nvidia_drm.blacklist = true;
        nvidia_modeset.blacklist = true;
        nvidia.blacklist = true;
        nvidia-uvm.blacklist = true;
      };
    };
    services.xserver = {
      deviceSection = mkIf isNvidiaDriver (mkMerge [
        ''
          Driver "nvidia"
          Option "NoLogo" "True"
          Option "Coolbits" "28"
        ''
        (mkIf cfg.enableSoftwareI2c ''
          Option "RegistryDwords" "RMUseSwI2c=0x01;RMI2cSpeed=100"
        '')
      ]);
      displayManager.lightdm.extraConfig = mkIf cfg.dynamicBinding ''
        logind-check-graphical=false
      '';
    };
    systemd.services = mkIf cfg.dynamicBinding {
      nvidia-x11 = rec {
        restartIfChanged = false;
        path = [ pkgs.kmod ];
        script = mkMerge [
          ""
          (mkIf isNvidiaDriver ''
            modprobe -a nvidia-uvm nvidia
          '')
        ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          TimeoutSec = 15;
        };
      };
      display-manager = mkIf config.services.xserver.enable rec {
        wants = [ "nvidia-x11.service" ];
        after = wants;
        bindsTo = wants;
      };
    };
  };
}
