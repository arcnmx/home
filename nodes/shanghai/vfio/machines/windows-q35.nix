{ nixosConfig, config, lib, ... }: with lib; let
  amd = nixosConfig.hardware.cpu.info.vendorId == "AuthenticAMD";
in {
  config = {
    pci.devices = {
      bridge.settings = {
        id = "pci.1";
        driver = "pcie-pci-bridge";
        multifunction = true;
      };
      pcieport17.settings = {
        driver = "pcie-root-port";
        port = "0x17";
        chassis = 2;
        addr = "${config.pci.devices.bridge.settings.addr}.0x1";
      };
      pcieport18.settings = {
        driver = "pcie-root-port";
        port = "0x18";
        chassis = 1;
        addr = "${config.pci.devices.bridge.settings.addr}.0x2";
      };
    };
    machine.settings = {
      type = "q35";
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
  };
}
