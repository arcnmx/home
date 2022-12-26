{ config, lib, pkgs, ... }: with lib; let
  inherit (config.hardware) opengl;
  igpu = opengl.intel;
  openglPackages = pkgs: with pkgs; mkMerge [
    (mkIf opengl.vaapi.enable [ vaapiIntel ])
    (mkIf igpu.enable [ (if igpu.computeRuntime then intel-compute-runtime else intel-ocl) ])
  ];
in {
  options = {
    hardware.opengl.intel = {
      enable = mkEnableOption "Intel GPU" // {
        default = true;
      };
      generation = mkOption {
        type = types.int;
      };
      computeRuntime = mkOption {
        type = types.bool;
        default = igpu.generation > 7;
      };
    };
  };

  config = {
    nixpkgs.system = "x86_64-linux";
    environment.systemPackages = [ pkgs.i7z ];
    services.xserver = mkIf igpu.enable {
      videoDrivers = [ "intel" ];
      deviceSection = ''
        Option "TearFree" "true"
      '';
    };
    hardware = {
      cpu = {
        info = {
          vendorId = "GenuineIntel";
          threadsPerCore = mkOptionDefault 2;
        };
        intel.updateMicrocode = mkDefault true;
      };
      opengl = {
        extraPackages = mkIf igpu.enable (openglPackages pkgs);
        extraPackages32 = mkIf igpu.enable (openglPackages pkgs.driversi686Linux);
        intel.generation = mkMerge [
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
    };
  };
}
