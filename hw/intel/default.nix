{ config, lib, pkgs, ... }: with lib; let
  cfg = config.home.profileSettings.intel;
  openglPackages = with pkgs; [
    vaapiIntel libvdpau-va-gl vaapiVdpau
    (if cfg.graphics.computeRuntime then intel-compute-runtime else intel-ocl)
  ];
in {
  options = {
    home.profileSettings.intel = {
      graphics = {
       enable = mkEnableOption "Intel iGPU";
        generation = mkOption {
          type = types.int;
        };
        computeRuntime = mkOption {
          type = types.bool;
          default = cfg.graphics.generation > 7;
        };
      };
    };
  };

  config = {
    environment.systemPackages = [ pkgs.i7z ];
    hardware = {
      cpu.intel.updateMicrocode = mkDefault true;
      opengl.extraPackages = mkIf cfg.graphics.enable openglPackages;
    };
    home.profileSettings.intel.graphics.generation = mkMerge [
      (mkIf (config.boot.kernel.arch == "westmere") 5)
      (mkIf (config.boot.kernel.arch == "sandybridge") 6)
      (mkIf (config.boot.kernel.arch == "ivybridge") 7)
      (mkIf (config.boot.kernel.arch == "haswell") 7)
      (mkIf (config.boot.kernel.arch == "broadwell") 8) # braswell
      (mkIf (config.boot.kernel.arch == "skylake") 9) # apollo lake, kaby lake, coffee lake, amber lake, whiskey lake, comet lake, gemini lake
      (mkIf (config.boot.kernel.arch == "icelake") 11)
      # Xe-LP = Gen12
    ];
  };
}
