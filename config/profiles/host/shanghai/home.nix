{ config, pkgs, lib, ... }: with lib; {
  options = {
    home.profiles.host.shanghai = mkEnableOption "hostname: shanghai";
  };

  config = mkMerge [ {
  } (mkIf config.home.profiles.host.shanghai {
    home.profiles.trusted = true;
    home.profiles.personal = true;
    home.profiles.gui = true;
    home.profiles.hw.nvidia = true;
    home.profiles.hw.x370gpc = true;

    xdg.configFile."i3status/config".source = ./files/i3status;

    home.packages = [ pkgs.paswitch ];
    services.konawall.tags = ["score:>=200" "width:>=1600" "rating:safe"];
    home.shell.functions = {
      _paswitch_sinks = ''
        ${pkgs.pulseaudio}/bin/pactl list short sinks | ${pkgs.coreutils}/bin/cut -d $'\t' -f 2
      '';
      _paswitch = ''
        _alternative 'preset:preset:(headphones speakers)' 'sink:sink:($(_paswitch_sinks))'
      '';
    };
    programs.zsh.initExtra = ''
      compdef _paswitch paswitch
    '';
    programs.mpv = {
      config = {
        # may as well use the excess RAM for something
        demuxer-max-bytes = "2000MiB";
        demuxer-max-back-bytes = "250MiB";
      };
    };

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
  }) ];
}
