{ config, lib, ... }: with lib; {
  config = {
    networking = {
      hostId = "a1184652";
      useDHCP = false;
      useNetworkd = true;
      firewall = {
        free.base = 32000;
        allowedTCPPorts = [
          6600 # mpd
        ];
        allowedTCPPortRanges = [
          rec { from = config.networking.firewall.free.base + 101; to = from + 1; } # http/opus out
        ];
      };
    };
    #home.nixbld.enable = true; # TODO
    services.mosh.enable = true;
  };
}
