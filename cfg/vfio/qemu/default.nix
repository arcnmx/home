{ config, lib, pkgs, inputs, trusted, ... }: with lib; {
  options.hardware.vfio.qemu = {
    enable = mkEnableOption "QEMU VMs";
    package = mkOption {
      type = types.package;
      default = pkgs.qemu-vfio or pkgs.qemu;
    };
    machines = mkOption {
      type = types.attrsOf (types.submoduleWith {
        modules = [
          (import (inputs.arc + "/modules/misc")).qemu
          ./machine.nix
          ./memory.nix
          ./smp.nix
          ./exec.nix
          ./ovmf.nix
          ./pci.nix
          ./usb.nix
          ./disks.nix
          ./vfio.nix
        ];
        specialArgs = {
          nixosConfig = config;
          inherit pkgs inputs trusted;
        };
      });
      default = { };
    };
  };
}
