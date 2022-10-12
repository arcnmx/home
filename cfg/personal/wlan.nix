{ config, lib, ... }: with lib; let
  cfg = config.networking.wireless;
  macAddresses = {
    ax210 = "d8:f8:83:36:81:b6";
    ac7265 = "00:15:00:ec:c6:51";
    ax200 = "a4:b1:c1:d9:14:df"; # integrated in x570am
  };
in {
  options.networking.wireless = with types; {
    mainInterface = {
      rename = mkOption {
        type = types.bool;
        default = cfg.mainInterface.arcCard != null && !cfg.iwd.enable;
      };
      name = mkOption {
        type = nullOr str;
        default = null;
      };
      arcCard = mkOption {
        type = nullOr (enum (attrNames macAddresses));
        default = null;
      };
    };
  };
  config = {
    networking.wireless = {
      mainInterface.name = mkMerge [
        (mkIf cfg.iwd.enable (mkOverride 750 "wlan0"))
        (mkIf cfg.mainInterface.rename (mkOverride 500 "wlan"))
      ];
    };
    systemd.network.links."10-wlan" = mkIf cfg.mainInterface.rename {
      matchConfig = {
        MACAddress = macAddresses.${cfg.mainInterface.arcCard};
      };
      linkConfig = {
        Name = cfg.mainInterface.name;
        NamePolicy = "";
      };
    };
  };
}
