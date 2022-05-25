{ lib, ... }: with lib; {
  config = {
    networking = {
      hostId = "451b608e";
      nftables.ruleset = mkAfter (builtins.readFile ./nftables.conf);
      useNetworkd = true;
      useDHCP = false;
    };

    services.openssh.ports = [ 22 64022 ];
    #networking.connman.extraFlags = ["-I" "eth0" "-I" "wlan0"]; # why did I have this there? these don't even exist?
  };
}
