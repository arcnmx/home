{ nixosConfig, config, pkgs, lib, ... }: with lib; let
  # `gio open` (which firefox uses via libgio) picks from a list of hard-coded terminals:
  # https://github.com/GNOME/glib/blob/cbb2a51a5b45925b04f3bf7d06ade59c00154bdf/gio/gdesktopappinfo.c#L2612
  xdg-open = (pkgs.writeShellScriptBin "xdg-open" ''
    export PATH="$PATH:${gioTerminal}/bin"
    exec ${pkgs.glib.bin}/bin/gio open "$@"
  '').overrideAttrs (_: {
    meta.priority = 3;
  });
  gioTerminal = pkgs.writeShellScriptBin "rxvt" ''
    if [[ ''${1-} != -e ]]; then
      exec ${pkgs.rxvt-unicode-arc}/bin/urxvtc "$@"
    fi
    shift
    exec ${pkgs.rxvt-unicode-arc}/bin/urxvtc -e ''${SHELL-bash} -ic "$*"
  '';
in {
  imports = [
    ./xresources.nix
    ./idle.nix
    ../i3.nix
    ../imv.nix
    ../polybar
    ../firefox
    ../dunst
    ../mpv
  ];

  options = {
    gtk.dpiScale = mkOption {
      type = types.float;
      default = config.home.gui.dpiScale;
    };
    home.gui = {
      dpi = mkOption {
        type = types.float;
        default = nixosConfig.hardware.display.dpi;
      };
      dpiScale = mkOption {
        type = types.float;
        default = nixosConfig.hardware.display.fontScale;
      };
    };
  };

  config = {
    home.profileSettings.base.clip = pkgs.clip.override { enableWayland = config.wayland.windowManager.sway.enable; };
    home.file = {
      ".xinitrc" = {
        executable = true;
        text = ''
          #!${pkgs.bash}/bin/bash
          . ~/.xsession
        '';
      };
    };
    home.shell = {
      functions = {
        discord = ''
          PULSE_PROP="media.role=phone" nix shell --impure nixpkgs#discord -c Discord "$@"
        '';
        ffr = ''
          nix shell nixpkgs#flashplayer-standalone -c flashplayer http://www.flashflashrevolution.com/~velocity/R^3.swf
        '';
        monstercatfm = ''
          mplay ytdl://http://twitch.tv/monstercat
        '';
      };
    };
    home.sessionVariables = mkMerge [
      (mkIf (config.gtk.enable && config.gtk.dpiScale != 1.0) {
        GDK_DPI_SCALE = toString config.gtk.dpiScale;
      })
      (mkIf (config.gtk.dpiScale != 1.0) {
        QT_FONT_DPI = toString (config.home.gui.dpi * config.gtk.dpiScale);
      })
    ];
    xdg.open = "${xdg-open}/bin/xdg-open";
    programs.zsh.loginExtra = mkIf nixosConfig.services.xserver.displayManager.startx.enable ''
      if [[ -z "''${TMUX-}" && -z "''${DISPLAY-}" && "''${XDG_VTNR-}" = 1 && $(${pkgs.coreutils}/bin/id -u) != 0 && $- == *i* ]]; then
        startx
      fi
    '';
    programs.zsh.initExtra = ''
      if [[ -n ''${ARC_PROMPT_RUN-} ]]; then
        source ${files/zshrc-run}
      fi
    '';
    home.packages = with pkgs; [
      config.services.konawall.konashow
      ffmpeg
      youtube-dl
      yt-dlp
      scrot
      xsel
      xorg.xinit
      xdg-utils
      xdg-open
      arc.packages.personal.emxc
      rxvt-unicode-arc
      mumble-develop
      gioTerminal
    ] ++ optionals config.gtk.enable [
      evince
      gnome.adwaita-icon-theme
    ];

    services.picom = {
      enable = mkDefault true;
      package = mkDefault pkgs.picom-next;
      opacityRules = [
        # https://wiki.archlinux.org/index.php/Picom#Tabbed_windows_(shadows_and_transparency)
        "100:class_g = 'URxvt' && !_NET_WM_STATE@:32a"
          "0:_NET_WM_STATE@[0]:32a *= '_NET_WM_STATE_HIDDEN'"
          "0:_NET_WM_STATE@[1]:32a *= '_NET_WM_STATE_HIDDEN'"
          "0:_NET_WM_STATE@[2]:32a *= '_NET_WM_STATE_HIDDEN'"
          "0:_NET_WM_STATE@[3]:32a *= '_NET_WM_STATE_HIDDEN'"
          "0:_NET_WM_STATE@[4]:32a *= '_NET_WM_STATE_HIDDEN'"
      ];
      shadowExclude = [
        "_NET_WM_STATE@:32a *= '_NET_WM_STATE_HIDDEN'"
      ];
    };
    programs.weechat.config = {
      urlgrab.default.localcmd = "${config.programs.firefox.package}/bin/firefox '%s'";
      # TODO: remotecmd?
    };
    services.playerctld.enable = true;

    services.gpg-agent.pinentryFlavor = "gtk2";
    services.redshift = {
      tray = false;
    };
    services.konawall = {
      enable = true;
      interval = "20m";
    };
    services.watchdogs.services = {
      i3 = {
        target = "i3-session.target";
        inherit (config.xsession.windowManager.i3) enable;
        command = [ "${config.xsession.windowManager.i3.package}/bin/i3-msg" "-t" "get_version" ];
      };
      display = {
        target = "graphical-session.target";
        inherit (config.xsession) enable;
        command = [ "${pkgs.xorg.xset}/bin/xset" "q" ];
      };
    };
    home.shell.aliases = {
      konawall = mkIf config.services.konawall.enable "systemctl --user restart konawall.service";
      chrome = mkIf (!config.programs.google-chrome.enable && !config.programs.chromium.enable)
        "nix shell --impure --builders '' nixpkgs-big#google-chrome -c google-chrome-stable";
      oryx = "chrome https://configure.ergodox-ez.com/train";
      parsec = "nix run --impure --builders '' nixpkgs#parsec-bin";
      pavucontrol = "nix run nixpkgs#pavucontrol";
    };
    home.shell.functions = {
      soffice = ''nix shell nixpkgs-big#libreoffice-fresh -c soffice "$@"'';
    };

    xsession = {
      enable = true;
      profileExtra = ''
        export XDG_CURRENT_DESKTOP=i3
        ${pkgs.xorg.setxkbmap}/bin/setxkbmap -option numpad:microsoft
        ${pkgs.xorg.setxkbmap}/bin/setxkbmap -option numpad:shift3
        ${pkgs.xorg.setxkbmap}/bin/setxkbmap -option ctrl:nocaps

        ${pkgs.rxvt-unicode-arc}/bin/urxvtd &

        export LESS=''${LESS//F}
      '';
        #${pkgs.xorg.xrandr}/bin/xrandr > /dev/null 2>&1
    };
    gtk = {
      enable = true;
      font = {
        name = "sans-serif ${toString (config.lib.gui.fontSize 12 / config.gtk.dpiScale)}";
      };
      iconTheme = {
        name = "Adwaita";
        package = pkgs.gnome.adwaita-icon-theme;
      };
      theme = {
        name = "Adwaita";
        package = pkgs.gnome.gnome-themes-extra;
      };
      gtk3 = {
        extraConfig = {
          gtk-application-prefer-dark-theme = false;
          gtk-fallback-icon-theme = "gnome";
        };
      };
    };

    lib.gui = {
      dpiSize = size: config.home.gui.dpiScale * config.home.gui.dpi / 96.0 * size;
      fontSize = size: config.home.gui.dpiScale * size;
      fontSizeStr = size: toString (config.lib.gui.fontSize size);
    };
  };
}
