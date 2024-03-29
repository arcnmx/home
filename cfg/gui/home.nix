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
    ./dpms-standby.nix
    ./idle.nix
    ./dpi.nix
    ../i3.nix
    ../imv.nix
    ../polybar
    ../firefox
    ../dunst
    ../mpv
  ];

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
          local FILE=$(mktemp --tmpdir tmp.XXXXXXXX.swf)
          local URL="http://www.flashflashrevolution.com/~velocity/R^3.swf"
          curl -Lsqo "$FILE" "$URL" &&
            nix shell nixpkgs#lightspark -c lightspark --url "$URL" "$FILE"
        '';
        twitch = ''
          local URL="https://twitch.tv/$1"
          shift
          mpv "$URL" "$@"
        '';
        monstercatfm = ''
          mplay ytdl://http://twitch.tv/monstercat
        '';
      };
    };
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
      obsidian = "nix run --impure --builders '' nixpkgs#obsidian >/dev/null 2>/dev/null </dev/null";
      pavucontrol = "nix run nixpkgs#pavucontrol";
    };
    home.shell.functions = {
      soffice = ''nix shell nixpkgs-big#libreoffice-fresh -c soffice "$@"'';
      pdf = ''evince "$@" 2>/dev/null &'';
      scrot = ''
        cd ${config.xdg.userDirs.pictures}
        command scrot "$@"
      '';
    };
    home.scratch.linkDirs = [
      ".config/Microsoft"
      ".config/discord/Code Cache"
      ".parsec"
      ".cache/sponsorblock_shared"
      ".cache/google-chrome/Default/Code Cache"
      ".local/share/Google" # Android Studio
    ];

    xsession = {
      enable = mkDefault nixosConfig.services.xserver.enable;
      profileExtra = ''
        export XDG_CURRENT_DESKTOP=i3
        ${pkgs.xorg.setxkbmap}/bin/setxkbmap -option numpad:microsoft
        ${pkgs.xorg.setxkbmap}/bin/setxkbmap -option numpad:shift3
        ${pkgs.xorg.setxkbmap}/bin/setxkbmap -option ctrl:nocaps

        ${pkgs.rxvt-unicode-arc}/bin/urxvtd &

        export LESS=''${LESS//F}
      '';
      initExtra = let
        inherit (nixosConfig.hardware.display) dpms;
      in mkIf (dpms.enable && dpms.screensaverCycleSeconds != 600) ''
        ${getExe pkgs.xorg.xset} s ${toString dpms.screensaverSeconds} ${toString dpms.screensaverCycleSeconds}
      '';
    };
    gtk = {
      enable = true;
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
  };
}
