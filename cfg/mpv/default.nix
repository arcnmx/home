{ meta, base16, nixosConfig, config, pkgs, lib, ... } @ args: with lib; let
  mpv = "${config.programs.mpv.finalPackage}/bin/mpv";
in {
  imports = [
    ./syncplay.nix
  ];

  programs.mpv = {
    enable = true;
    scripts = with pkgs.mpvScripts; [
      sponsorblock mpris paused
    ];
    config = {
      input-default-bindings = false;
      screenshot-directory = replaceStrings [ "$HOME" ] [ config.home.homeDirectory ] config.xdg.userDirs.pictures;

      hwdec = mkDefault "auto";

      vo = mkDefault "gpu";
      opengl-waitvsync = true;

      keep-open = true;

      volume-max = 200;
      osd-scale-by-window = false;
      osd-font-size = config.lib.gui.fontSize 26; # pixels at 720 window height, then scaled to real size
      osd-bar-h = 2.5; # 3.125 default
      osd-border-size = 2; # font border pixels, default 3
      osd-fractions = true;
      term-osd-bar = true;
      script-opts = concatStringsSep "," (mapAttrsToList (k: v: "${k}=${toString v}") {
        ytdl_hook-ytdl_path = "${pkgs.yt-dlp}/bin/yt-dlp";
        osc-layout = "slimbox";
        osc-vidscale = "no";
        osc-deadzonesize = 0.75;
        osc-minmousemove = 4;
        osc-hidetimeout = 2000;
        osc-valign = 0.9;
        osc-timems = "yes";
        osc-seekbarstyle = "knob";
        osc-seekbarkeyframes = "no";
        osc-seekrangestyle = "slider";
      });
    };
    bindings = let
      vim = {
        "l" = "seek 5";
        "h" = "seek -5";
        "k" = "seek 60";
        "j" = "seek -60";
        "Ctrl+l" = "seek 1 exact";
        "Ctrl+h" = "seek -1 exact";
        "Ctrl+L" = "sub-seek 1";
        "Ctrl+H" = "sub-seek -1";
        "Ctrl+k" = "add chapter 1";
        "Ctrl+j" = "add chapter -1";
        "Ctrl+K" = "playlist-next";
        "Ctrl+J" = "playlist-prev";
        "Alt+h" = "frame-back-step";
        "Alt+l" = "frame-step";
        "w" = "screenshot";
        "W" = "screenshot video";
        "Ctrl+w" = "screenshot window";
        "Ctrl+W" = "screenshot each-frame";
        "L" = "add volume 2";
        "H" = "add volume -2";
        "Alt+H" = "add audio-delay -0.100";
        "Alt+L" = "add audio-delay 0.100";
        "d" = "drop-buffers";
        "Ctrl+d" = "quit";
      };
      common = {
        "`" = "cycle mute";
        "SPACE" = "cycle pause";

        "Ctrl+0" = "set speed 1.0";
        "Ctrl+)" = "set speed 1.004"; # ctrl+shift+0
        "Ctrl+=" = "multiply speed 1.1";
        "Ctrl+-" = "multiply speed 1/1.1";

        "o" = "show-progress";
        "O" = "script-message show_osc_dur 5";
        "?" = "script-binding stats/display-stats-toggle";
        "Ctrl+/" = "script-binding console/enable";

        "Ctrl+r" = "loadfile \${path}";
        "Ctrl+R" = "video-reload";

        "F1" = "cycle sub";
        "F2" = "cycle audio";
        "Ctrl+p" = "cycle video";

        "1" = "set volume 10";
        "2" = "set volume 20";
        "3" = "set volume 30";
        "4" = "set volume 40";
        "5" = "set volume 50";
        "6" = "set volume 60";
        "7" = "set volume 70";
        "8" = "set volume 80";
        "9" = "set volume 90";
        ")" = "set volume 150";
        "0" = "set volume 100";
      };
      directional = {
        "RIGHT" = vim."l";
        "LEFT" = vim."h";
        "UP" = vim."k";
        "DOWN" = vim."j";
        "Ctrl+RIGHT" = vim."Ctrl+l";
        "Ctrl+LEFT" = vim."Ctrl+h";
        "Ctrl+Shift+LEFT" = vim."Ctrl+H";
        "Ctrl+Shift+RIGHT" = vim."Ctrl+L";
        "Ctrl+UP" = vim."Ctrl+k";
        "Ctrl+DOWN" = vim."Ctrl+j";
        "Ctrl+Shift+UP" = vim."Ctrl+K";
        "Ctrl+Shift+DOWN" = vim."Ctrl+J";
        "Alt+LEFT" = vim."Alt+h";
        "Alt+RIGHT" = vim."Alt+l";
        "MBTN_RIGHT" = common."SPACE";
        "m" = common."`";
        "WHEEL_UP" = vim."L";
        "WHEEL_DOWN" = vim."H";
      };
    in vim // common // optionalAttrs false directional;
  };
  home.shell = {
    functions = {
      mpa = ''
        PULSE_PROP="media.role=music" ${mpv} --no-video "$@"
      '';
      mpv = ''
        ( # subshell important!
          echo 200 > /proc/self/oom_score_adj
          PULSE_PROP="media.role=video" ${mpv} --force-window=immediate "$@"
        )
      '';
    };
  };
}
