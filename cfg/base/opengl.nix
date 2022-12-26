{ config, lib, pkgs, ... }: with lib; let
  cfg = config.hardware.opengl;
  openglPackages = pkgs: with pkgs; mkMerge [
    (mkIf cfg.mesa.enable [ mesa.drivers ])
    (mkIf (cfg.vaapi.enable && cfg.vdpau.enable) [ vaapiVdpau libvdpau-va-gl ])
  ];
in {
  options = {
    hardware.opengl = {
      opencl.enable = mkEnableOption "OpenCL" // {
        default = true;
      };
      vaapi.enable = mkEnableOption "VA-API" // {
        default = true;
      };
      vdpau.enable = mkEnableOption "VDPAU" // {
        default = true;
      };
      mesa.enable = mkEnableOption "MESA";
    };
  };
  config = {
    hardware.opengl = {
      extraPackages = openglPackages pkgs;
      extraPackages32 = openglPackages pkgs.driversi686Linux;
    };
    services.xserver.videoDrivers = mkAfter [
      "modesetting"
      "fbdev"
    ];
  };
}
