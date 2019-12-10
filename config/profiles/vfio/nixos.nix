{ config, lib, ... }: with lib; {
  options = {
    home.profiles.vfio = mkEnableOption "VFIO";
  };

  config = mkIf config.home.profiles.vfio {
    boot = {
      initrd.kernelModules = ["vfio" "vfio_iommu_type1" "vfio_pci" "vfio_virqfd"];
      extraModprobeConfig = ''
        options kvm ignore_msrs=1
      '';
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
    # TODO: arcnmx/arch-forcefully-remove-bootfb-dkms
  };
}
