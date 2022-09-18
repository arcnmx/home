{ lib, config, ... }: with lib; {
  imports = [ ./devices.nix ./machines ];
  config = {
    systemd.network.networks.br = {
      matchConfig.Name = "br";
      gateway = [ "10.1.1.1" ];
    };
    services.xserver = {
      deviceSection = mkMerge [
        # NOTE: this is decimal, be careful! IDs are typically shown in hex
        #''BusID "PCI:39:0:0"'' # primary GPU
        #''BusID "PCI:40:0:0"'' # secondary GPU
        ''BusID "PCI:05:0:0"'' # tertiary (chipset slot) GPU
      ];
    };
    users.users.kat.extraGroups = [ "kvm" "plugdev" ];
    networking.firewall = {
      allowedUDPPorts = [
        4011 # scream goliath
      ];
    };
  };
}
