{ config, pkgs, lib, ... } @ args: with lib; {
  imports = [
    ./xresources.nix
    ./i3.nix
  ];

  options = {
    home.profiles.gui = mkEnableOption "graphical system";
    home.gui.fontDpi = mkOption {
      type = types.float;
      default = 96.0;
    };
  };

  config = mkIf config.home.profiles.gui {
    home.file = {
      ".xinitrc" = {
        executable = true;
        text = ''
          #!${pkgs.bash}/bin/bash
          ${pkgs.xorg.xrdb}/bin/xrdb -merge ~/.Xresources
          . ~/.xsession
        '';
      };
    };
    home.shell = {
      functions = {
        mradio = mkIf config.home.profiles.trusted ''
          PULSE_PROP="media.role=music" ${pkgs.mpv}/bin/mpv --cache=no --cache-backbuffer=0 --cache-seek-min=0 --cache-secs=1 http://${config.network.yggdrasil.shanghai.address}:32101
        '';
        mpa = ''
          PULSE_PROP="media.role=music" ${pkgs.mpv}/bin/mpv --no-video "$@"
        '';
        mpv = ''
          PULSE_PROP="media.role=video" ${pkgs.mpv}/bin/mpv "$@"
        '';
        discord = ''
          PULSE_PROP="media.role=phone" ${pkgs.discord}/bin/discord "$@" &
        '';
        ffr = ''
          ${pkgs.flashplayer-standalone}/bin/flashplayer http://www.flashflashrevolution.com/~velocity/R^3.swf
        '';
        monstercatfm = ''
          mpa http://twitch.tv/monstercat
        '';
      };
    };
    programs.zsh.loginExtra = ''
      if [[ -z "''${TMUX-}" && -z "''${DISPLAY-}" && "''${XDG_VTNR-}" = 1 && $(${pkgs.coreutils}/bin/id -u) != 0 ]]; then
        ${pkgs.xorg.xinit}/bin/startx
      fi
    '';
    home.packages = with pkgs; [
      feh
      ffmpeg
      epdfview
      firefox
      youtube-dl
      mpv
      scrot
      xclip
      xorg.xinit
      xdg_utils-mimi
      rxvt_unicode-with-plugins
      luakit-develop
      libreoffice-fresh
    ];

    home.sessionVariables = {
      # firefox
      MOZ_WEBRENDER = "1";
      MOZ_USE_XINPUT2 = "1";
    };
    programs.mpv = {
      enable = true;
      config = {
        hwdec = mkDefault "auto";

        vo = mkDefault "gpu";
        opengl-waitvsync = "yes";

        keep-open = "yes";

        cache-default = "500000";
        cache-secs = "2";
      };
    };
    xdg.configFile = {
      "mimeapps.list".text = ''
        [Default Applications]
        text/html=luakit.desktop
        x-scheme-handler/http=luakit.desktop
        x-scheme-handler/https=luakit.desktop
        image/jpeg=feh.desktop
        image/png=feh.desktop
        image/gif=feh.desktop
        application/pdf=epdfview.desktop
        text/plain=vim.desktop
        application/xml=vim.desktop
      '';
      "tridactyl" = {
        source = ./files/tridactyl;
        recursive = true;
      };
      "luakit" = {
        source = ./files/luakit;
        recursive = true;
      };
      "luakit/rc/nix.lua".source = pkgs.substituteAll {
        src = ./files/luakit-nix.lua;
        pass = pkgs.pass-otp;
      };
      "luakit/pass".source = pkgs.fetchFromGitHub {
        owner = "arcnmx";
        repo = "luakit-pass";
        rev = "7d242c6570d14edba71b047c91631110c703a95d";
        sha256 = "1k2gnnq92axdshd629svr4vzv7m0sl5gijb1bsvivc4hq3j85vj2";
      };
      "luakit/paste".source = pkgs.fetchFromGitHub {
        owner = "arcnmx";
        repo = "luakit-paste";
        rev = "0df1e777ca3ff9bf20532288ea86992024491bc3";
        sha256 = "1g3di8qyah0zgkx6lmk7h3x44c3w5xiljn76igmd66cmqlk6lg6q";
      };
      "luakit/unique_instance".source = pkgs.fetchFromGitHub {
        owner = "arcnmx";
        repo = "luakit-unique_instance";
        rev = "e35d5c27327a29797f4eb5a2cbbc2c1b569a36ad";
        sha256 = "0l7g83696pmws40nhfdg898lv9arkc7zc5qa4aa9cyickb9xgadz";
      };
      "luakit/plugins".source = pkgs.fetchFromGitHub {
        owner = "luakit";
        repo = "luakit-plugins";
        rev = "eb766fca92c1e709f8eceb215d2a2716b0748806";
        sha256 = "0f1cq0m22bdd8a3ramlwyymlp8kjz9mcbfdcyhb5bw8iw4cmc8ng";
      };
      /*"sway/config".text = ''
        # man 5 sway

        # font "Droid Sans Mono Dotted 8"
        exec_always xrdb -I$HOME -load ~/.Xresources
        exec_always urxvtd

        smart_gaps on
        seamless_mouse on

        include ${config.xdg.configHome}/i3/config
        #include /etc/sway/config.d/*

        bindsym $mod+bracketleft exec ${pkgs.swaylock}/bin/swaylock -u -c 111111
        bindsym $mod+p exec ${pkgs.acpilight}/bin/xbacklight -set $([[ $(${pkgs.acpilight}/bin/xbacklight -get) = 0 ]] && echo 100 || echo 0)

        output * background #111111 solid_color
      '';*/
    };

    services.konawall = {
      enable = true;
      interval = "20m";
    };

    xsession = {
      enable = true;
      profileExtra = ''
        export XDG_CURRENT_DESKTOP=i3
        ${pkgs.xorg.setxkbmap}/bin/setxkbmap -option numpad:microsoft
        ${pkgs.xorg.setxkbmap}/bin/setxkbmap -option numpad:shift3
        ${pkgs.xorg.setxkbmap}/bin/setxkbmap -option ctrl:nocaps

        ${pkgs.xcompmgr}/bin/xcompmgr &
        ${pkgs.rxvt_unicode-with-plugins}/bin/urxvtd &

        export LESS=''${LESS://F}
      '';
        #${pkgs.xorg.xrandr}/bin/xrandr > /dev/null 2>&1
    };
    gtk = {
      enable = true;
      font = {
        name = "sans-serif ${config.lib.gui.fontSizeStr 12}";
      };
      iconTheme = {
        name = "Adwaita";
        package = pkgs.gnome3.adwaita-icon-theme;
      };
      theme = {
        name = "Adwaita";
        package = pkgs.gnome3.gnome-themes-standard;
      };
      gtk3 = {
        extraConfig = {
          gtk-application-prefer-dark-theme = false;
          gtk-fallback-icon-theme = "gnome";
        };
      };
    };

    lib.gui = {
      fontSize = size: config.home.gui.fontDpi * size / 96;
      fontSizeStr = size: toString (config.lib.gui.fontSize size);
    };
  };
}
