{ lib, ... }: with lib; {
  config = {
    networking = {
      hostId = "451b608e";
      useNetworkd = true;
      useDHCP = false;
      firewall = {
        free.base = 64000;
      };
    };

    #networking.connman.extraFlags = ["-I" "eth0" "-I" "wlan0"]; # why did I have this there? these don't even exist?
  };
}
