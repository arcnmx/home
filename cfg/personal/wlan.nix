{ config, lib, ... }: with lib; let
  cfg = config.networking.wireless;
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
        type = nullOr str;
        default = null;
      };
      isMain = mkOption {
        type = bool;
        default = false;
      };
    };
    arcCards = mkOption {
      type = attrs;
      default = { };
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
        MACAddress = let
          mac = cfg.arcCards.${cfg.mainInterface.arcCard}.mac or null;
        in mkIf (mac != null) mac;
      };
      linkConfig = {
        Name = cfg.mainInterface.name;
        NamePolicy = "";
      };
    };
  };
}
