{ config, lib, ... }: with lib; {
  config = {
    services.hostapd = mapAttrs (_: mkDefault) {
      enable = true;
      interface = config.networking.wireless.mainInterface.name;
      countryCode = "CA";
      hwMode = "g";
      channel = 6;
    } // {
      extraConfig = ''
        bridge=br
        ieee80211n=1
        ieee80211ac=1
        wmm_enabled=1
        wpa_pairwise=TKIP
        rsn_pairwise=CCMP
        ht_capab=[HT40+][SHORT-GI-20][SHORT-GI-40][TX-STBC][RX-STBC1][DSSS_CCK-40]
      '';
    };
  };
}
