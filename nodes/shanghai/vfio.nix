{ lib, config, ... }: with lib; {
  config = {
    systemd.network.networks.br = {
      matchConfig.Name = "br";
      gateway = [ "10.1.1.1" ];
    };
    services.udev.extraRules = ''
      # my VM disks
      SUBSYSTEM=="block", ACTION=="add", ATTRS{model}=="INTEL SSDSC2BP48", ATTRS{wwid}=="naa.55cd2e404b6f84e5", OWNER="arc"
      SUBSYSTEM=="block", ACTION=="add", ATTR{partition}=="4", ATTR{size}=="125829120", ATTRS{wwid}=="eui.6479a741e0203d76", OWNER="arc"
      SUBSYSTEM=="block", ACTION=="add", ATTR{partition}=="6", ATTR{size}=="134217728", ATTRS{wwid}=="eui.002303563000ad1b", OWNER="arc"
    '';
    services.xserver = {
      deviceSection = mkMerge [
        # NOTE: this is decimal, be careful! IDs are typically shown in hex
        #''BusID "PCI:39:0:0"'' # primary GPU
        #''BusID "PCI:40:0:0"'' # secondary GPU
        ''BusID "PCI:05:0:0"'' # tertiary (chipset slot) GPU
      ];
    };
    boot = {
      modprobe.modules = {
        vfio-pci = let
          vfio-pci-ids = [
            # "10de:1c81" "10de:0fb9" # 1050
            # "10de:1f82" "10de:10fa" # 1660
            "10de:2206" "10de:1aef" # 3080
          ];
        in mkIf (vfio-pci-ids != [ ]) {
          options.ids = concatStringsSep "," vfio-pci-ids;
        };
      };
    };
  };
}
