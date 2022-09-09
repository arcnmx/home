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
          ./ivshmem.nix
          ./smp.nix
          ./exec.nix
          ./ovmf.nix
          ./pci.nix
          ./usb.nix
          ./disks.nix
          ./vfio.nix
          ./audio.nix
          ./spice.nix
          ./scream.nix
          ./lookingglass.nix
          ./qmp.nix ./qga.nix
          ./qemucomm.nix
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
