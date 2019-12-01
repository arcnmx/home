{ config, pkgs, lib, ... }: with lib; {
  options = {
    home.profiles.hw.ryzen = mkEnableOption "AMD Ryzen CPU";
  };

  config = mkIf config.home.profiles.hw.ryzen {
    boot.kernel.sysctl = {
      "kernel.randomize_va_space" = 0; # related to https://bugzilla.kernel.org/show_bug.cgi?id=196683
    };
    boot.kernelModules = [
      "msr" # for zenstates
      "kvm-amd"
    ];
    environment.etc = {
      "sensors.d/ryzen".text = ''
        chip "k10temp-pci-00c3"
            label temp1 "Core"
      '';
    };
    environment.systemPackages = [pkgs.zenstates];
  };
}
