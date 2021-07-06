{ config, pkgs, lib, ... }: with lib; {
  options = {
    home.profiles.hw.ryzen = mkEnableOption "AMD Ryzen CPU";
  };

  config = mkIf config.home.profiles.hw.ryzen {
    boot = {
      customKernel = mkDefault true;
      kernelPackages = pkgs.linuxPackages_bleeding;
      kernelParams = ["amd_iommu=on"];
      kernelModules = [
        "msr" # for zenstates
        "ryzen_smu" # for ryzen-monitor
        "kvm-amd"
      ];
      extraModulePackages = with config.boot.kernelPackages; [ ryzen-smu zenpower ];
    };
    hardware.cpu.amd.updateMicrocode = true;
    environment.etc = {
      "sensors3.conf".text = ''
        chip "k10temp-pci-00c3"
            label temp1 "Core"
      '';
    };
    environment.systemPackages = with pkgs; [
      lm_sensors
      ryzen-smu-monitor_cpu
      ryzen-monitor
    ];
  };
}
