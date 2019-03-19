{ config, pkgs, lib, ... }: with lib; {
  options = {
    home.profiles.host.shanghai = mkEnableOption "hostname: shanghai";
  };

  config = mkIf config.home.profiles.host.shanghai {
    home.profiles.trusted = true;

    xdg.configFile."i3status/config".source = ./files/i3status;

    home.packages = [ ]; # TODO: this
    services.konawall.tags = ["score:>=200" "width:>=1600" "rating:safe"];

    systemd.user.services.getquote = {
      Unit = {
        Description = "getquote";
      };
      Service = {
        Type = "simple";
        ExecStart = "${config.home.homeDirectory}/projects/gensokyo/ledger/update_prices";
      };
    };

    systemd.user.timers.konawall = {
      Timer = {
        OnCalendar = "Mon..Fri *-*-* 18:00:00";
      };
      Install.WantedBy = ["timers.target"];
    };
  };
}
