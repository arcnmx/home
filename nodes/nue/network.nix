{ lib, ... }: with lib; {
  config = {
    networking = {
      hostId = "68d05cda";
      useNetworkd = true;
      useDHCP = false;
      firewall = {
        free.base = 62000;
      };
      wireless.mainInterface.arcCard = "ax210";
    };
  };
}
