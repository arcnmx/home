{ extern, pkgs, config, lib, ... }: with lib; let
  inherit (config.networking) enableIPv6;
  cfg = config.services.ddclient;
  isCloudflare = cfg.protocol == "cloudflare";
in {
  config = {
    services.ddclient = {
      enable = mkDefault extern.enable;
      package = pkgs.ddclient-develop;
      quiet = true;
      username = mkIf isCloudflare "token";
      use = "no";
      domains = mkDefault [ ]; # why the hell is `[""]` the default???
      extraConfig = mkMerge [ (mkIf enableIPv6 ''
        usev6=webv6, webv6=https://ipv6.nsupdate.info/myip
      '') ''
        usev4=webv4, webv4=https://ipv4.nsupdate.info/myip
        max-interval=1d
      '' ];
      passwordFile = mkIf (cfg.enable && isCloudflare && extern.enable) extern.path.ddclient-secret;
    };
    systemd.services.ddclient = mkIf cfg.enable {
      serviceConfig = {
        TimeoutStartSec = 90;
      };
    };
  };
}
