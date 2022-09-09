{ config, trusted, lib, ... }: with lib; {
  imports = trusted.import.nixos "vfio/machines/macos";
  config = {
    cpu = {
      settings = {
        type = "Penryn";
        kvm = true;
        vendor = "GenuineIntel";
        vmware-cpuid-freq = true;
      };
      flags = {
        invtsc = true;
        x2apic = false;
      };
    };
    machine.settings = {
      type = "q35";
      accel = "kvm";
      usb = false;
      vmport = true;
      dump-guest-core = false;
    };
    smbios.smbios2.settings.type = 2;
  };
}
