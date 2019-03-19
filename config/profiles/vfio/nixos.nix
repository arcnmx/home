{ config, lib, ... }: with lib; {
  options = {
    home.profiles.vfio = mkEnableOption "VFIO";
  };

  config = mkIf config.home.profiles.vfio {
    boot.initrd.kernelModules = ["vfio" "vfio_iommu_type1" "vfio_pci" "vfio_virqfd"];
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
