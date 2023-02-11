{ nixosConfig, config, lib, ... }: with lib; let
  amd = nixosConfig.hardware.cpu.info.vendorId == "AuthenticAMD";
in {
  config = {
    pci.devices = {
      bridge.settings = {
        id = "pci.1";
        driver = "pci-bridge";
        chassis_nr = 1;
      };
      pci2.settings = {
        id = "pci.2";
        driver = "pci-bridge";
        chassis_nr = 2;
      };
    };
    machine.settings = {
      type = "pc-i440fx-5.0";
      accel = "kvm";
      usb = false;
      vmport = true;
      dump-guest-core = false;
    };
    cpu = {
      settings = {
        model = "host";
        topoext = true;
        host-cache-info = true;
        smep = false;
        kvm = false;
        hv_spinlocks = "0x1fff";
        hv_vendor_id = "ab12341234ab";
        hv_time = [];
        hv_relaxed = [];
        hv_vapic = mkIf amd [];
      };
      flags = {
        invtsc = true;
        amd-stibp = mkIf amd false;
      };
    };
    globals = {
      PIIX4_PM = {
        disable_s3 = 1;
        disable_s4 = 1;
      };
    };
  };
}
