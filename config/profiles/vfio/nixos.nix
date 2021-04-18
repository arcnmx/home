{ config, lib, pkgs, ... }: with lib; {
  options = {
    home.profiles.vfio = mkEnableOption "VFIO";
  };

  config = mkIf config.home.profiles.vfio {
    boot = {
      initrd.kernelModules = ["vfio" "vfio_iommu_type1" "vfio_pci" "vfio_virqfd"];
      modprobe.modules.kvm.options = {
        ignore_msrs = mkDefault true;
        report_ignored_msrs = mkDefault false;
      };
      extraModulePackages = [ config.boot.kernelPackages.forcefully-remove-bootfb ];
      kernelPatches = mkIf false [
        {
          name = "efifb-nobar";
          patch = ./files/efifb-nobar.patch;
        }
        # TODO: i915-vga-arbiter? https://aur.archlinux.org/cgit/aur.git/plain/i915-vga-arbiter.patch?h=linux-vfio
        # TODO: asc/iommu override? https://gitlab.com/Queuecumber/linux-acs-override/raw/master/workspaces/4.17/acso.patch
      ];
    };
    environment.etc."qemu/bridge.conf".text = "allow br";
    security.pam.loginLimits = [
      {
        domain = "@kvm";
        type = "-";
        item = "memlock";
        value = "unlimited";
      }
    ];
    security.wrappers = {
      # TODO: remove this, keep the VM network config entirely within the system nixos config instead?
      qemu-bridge-helper = {
        source = "${pkgs.qemu-vfio or pkgs.qemu}/libexec/qemu-bridge-helper";
      };
    };
    # TODO: arcnmx/arch-forcefully-remove-bootfb-dkms
  };
}
