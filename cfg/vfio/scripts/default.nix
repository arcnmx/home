{ config, lib, pkgs, ... }: with lib; {
  config = {
    lib.arc-vfio = {
      reserve-pci = pkgs.callPackage ./reserve-pci.nix { };
      unbind-vts = pkgs.callPackage ./unbind-vts.nix {
        forcefully-remove-bootfb = config.boot.kernelPackages.forcefully-remove-bootfb;
      };
    };
  };
}
