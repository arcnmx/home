{ pkgs, config, lib, ... }: with lib; {
  options = {
    boot.customKernel = mkOption {
      type = types.bool;
      default = hasInfix "-rc" config.boot.kernelPackages.kernel.version;
    };
    boot.kernelArch = mkOption {
      type = types.str;
      default = hostPlatform.linux-kernel.arch or hostPlatform.gcc.arch or "x86-64-v3";
    };
  };

  config = {
    boot.kernelPatches = mkIf config.boot.customKernel [
      (pkgs.kernelPatches.more_uarches.override { gccArch = config.boot.kernelArch; })
    ];
  };
}
