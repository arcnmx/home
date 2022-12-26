{ config, lib, pkgs, ... }: with lib; let
  inherit (config.hardware) opengl;
  cfg = opengl.amd;
  openglPackages = pkgs: with pkgs; mkMerge [
    (mkIf opengl.opencl.enable [ rocm-opencl-icd rocm-opencl-runtime ])
    (mkIf (cfg.vulkan.driver == "amdvlk") [ amdvlk ])
  ];
in {
  options = with types; {
    hardware.opengl.amd = {
      enableOpenCL = mkEnableOption "OpenCL";
      driver = mkOption {
        type = enum [ "amdgpu" "amdgpu-pro" ];
        default = "amdgpu";
      };
      vulkan.driver = mkOption {
        type = enum [ "radv" "amdvlk" ];
        default = "radv";
      };
    };
  };
  config = {
    services.xserver = {
      videoDrivers = [ cfg.driver ];
      deviceSection = ''
        Option "TearFree" "true"
        Option "VariableRefresh" "true"
      '';
    };
    hardware.opengl = {
      mesa.enable = cfg.driver == "amdgpu";
      extraPackages = openglPackages pkgs;
      extraPackages32 = openglPackages pkgs.driversi686Linux;
    };
  };
}
