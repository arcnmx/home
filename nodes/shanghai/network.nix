{ lib, ... }: with lib; {
  config = {
    networking = {
      hostId = "a1184652";
      useDHCP = false;
      useNetworkd = true;
      nftables.ruleset = mkAfter (builtins.readFile ./nftables.conf);
    };
    services.openssh.ports = [ 22 32022 ];
    #home.nixbld.enable = true; # TODO
    services.mosh = {
      enable = true;
      ports = {
        from = 32600;
        to = 32700;
      };
    };
  };
}
