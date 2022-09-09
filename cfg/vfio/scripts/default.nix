{ config, lib, pkgs, ... }: with lib; {
  config = {
    lib.arc-vfio = {
      map-disk = pkgs.callPackage ./map-disk.nix { };
      cow-disk = pkgs.callPackage ./cow-disk.nix { };
      reserve-pci = pkgs.callPackage ./reserve-pci.nix { };
      unbind-vts = pkgs.callPackage ./unbind-vts.nix {
        forcefully-remove-bootfb = config.boot.kernelPackages.forcefully-remove-bootfb;
      };
      alloc-hugepages = pkgs.callPackage ./alloc-hugepages.nix {
        systemd = config.systemd.package;
      };
    };
  };
}
