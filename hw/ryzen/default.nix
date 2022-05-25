{ config, pkgs, lib, ... }: with lib; {
  key = "AMD Ryzen CPU";

  config = {
    nixpkgs.system = "x86_64-linux";
    boot = {
      kernel = {
        arch = mkDefault "znver2";
        bleedingEdge = mkDefault true;
      };
      kernelParams = [ "amd_iommu=on" ];
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
      #zenstates
    ];
  };
}
