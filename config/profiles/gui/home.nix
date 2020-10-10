{ meta, config, pkgs, lib, ... } @ args: with lib; {
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
          PULSE_PROP="media.role=music" ${pkgs.mpv}/bin/mpv --cache=no --cache-backbuffer=0 --cache-seek-min=0 --cache-secs=1 http://shanghai:32101
        '';
        mpa = ''
          PULSE_PROP="media.role=music" ${pkgs.mpv}/bin/mpv --no-video "$@"
        '';
        mpv = ''
          PULSE_PROP="media.role=video" ${pkgs.mpv}/bin/mpv "$@"
        '';
        discord = ''
          PULSE_PROP="media.role=phone" ${pkgs.discord}/bin/Discord "$@" &
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
      youtube-dl
      mpv
      scrot
      xsel
      xorg.xinit
      xdg_utils-mimi
      rxvt-unicode-arc
      luakit-develop
      libreoffice-fresh # use `libreoffice` instead when this is broken, happens often ;-;
    ] ++ optionals config.gtk.enable [
      evince
      gnome3.adwaita-icon-theme
      gnome3.defaultIconTheme
    ];

    home.sessionVariables = {
      # firefox
      MOZ_WEBRENDER = "1";
      MOZ_USE_XINPUT2 = "1";
    };
    programs.weechat.config = {
      urlgrab.default.localcmd = "${config.programs.firefox.packageWrapped}/bin/firefox '%s'";
      # TODO: remotecmd?
    };
    programs.firefox = {
      enable = true;
      enableAdobeFlash = true;
      package = pkgs.firefox-bin-unwrapped;
      wrapperConfig = {
        browserName = "firefox";
        extraNativeMessagingHosts = with pkgs; [
          tridactyl-native
          bukubrow
        ];
      };
      profiles = {
        arc = {
          id = 0;
          isDefault = true;
          settings = {
            "browser.download.dir" = "${config.home.homeDirectory}/downloads";
            ${if config.home.hostName != null then "services.sync.client.name" else null} = config.home.hostName;
            "services.sync.engine.prefs" = false;
            "services.sync.engine.prefs.modified" = false;
            "services.sync.engine.passwords" = false;
            "services.sync.declinedEngines" = "passwords,adblockplus,prefs";
            "media.eme.enabled" = true; # whee drm
            "gfx.webrender.all.qualified" = true;
            "layers.acceleration.force-enabled" = true;
            "gfx.canvas.azure.accelerated" = true;
            "browser.ctrlTab.recentlyUsedOrder" = false;
            "privacy.resistFingerprinting.block_mozAddonManager" = true;
            "extensions.webextensions.restrictedDomains" = "";
            "tridactyl.unfixedamo" = true; # stop trying to change this file :(
            "tridactyl.unfixedamo_removed" = true; # wh-what happened this time?
            "browser.shell.checkDefaultBrowser" = false;
            "spellchecker.dictionary" = "en-CA";
            "browser.warnOnQuit" = false;
            "browser.startup.homepage" = "about:blank";
            "browser.contentblocking.category" = "strict";
            "browser.discovery.enabled" = false;
            "browser.newtab.privateAllowed" = true;
            "browser.newtabpage.enabled" = false;
            "browser.urlbar.placeholderName" = "";
            "extensions.privatebrowsing.notification" = false;
            "browser.startup.page" = 3;
            "devtools.chrome.enabled" = true;
            #"devtools.debugger.remote-enabled" = true;
            "devtools.inspector.showUserAgentStyles" = true;

            # hiding from mozilla
            "services.sync.prefs.sync.privacy.donottrackheader.value" = false;
            "services.sync.prefs.sync.browser.safebrowsing.malware.enabled" = false;
            "services.sync.prefs.sync.browser.safebrowsing.phishing.enabled" = false;
            "app.shield.optoutstudies.enabled" = true;
            "datareporting.healthreport.uploadEnabled" = false;
            "datareporting.policy.dataSubmissionEnabled" = false;
            "datareporting.sessions.current.clean" = true;
            "devtools.onboarding.telemetry.logged" = false;
            "toolkit.telemetry.updatePing.enabled" = false;
            "browser.ping-centre.telemetry" = false;
            "browser.newtabpage.activity-stream.asrouter.userprefs.cfr.addons" = false;
            "browser.newtabpage.activity-stream.asrouter.userprefs.cfr.features" = false;
            "toolkit.telemetry.bhrPing.enabled" = false;
            "toolkit.telemetry.enabled" = false;
            "toolkit.telemetry.firstShutdownPing.enabled" = false;
            "toolkit.telemetry.hybridContent.enabled" = false;
            "toolkit.telemetry.newProfilePing.enabled" = false;
            "toolkit.telemetry.reportingpolicy.firstRun" = false;
            "toolkit.telemetry.shutdownPingSender.enabled" = false;
            "toolkit.telemetry.unified" = false;
            "toolkit.telemetry.server" = "";
            "toolkit.telemetry.archive.enabled" = false;
            "browser.onboarding.enabled" = false;
            "experiments.enabled" = false;
            "network.allow-experiments" = false;
            "social.directories" = "";
            "social.remote-install.enabled" = false;
            "social.toast-notifications.enabled" = false;
            "social.whitelist" = "";
            "browser.safebrowsing.malware.enabled" = false;
            "browser.safebrowsing.blockedURIs.enabled" = false;
            "browser.safebrowsing.downloads.enabled" = false;
            "browser.safebrowsing.downloads.remote.enabled" = false;
            "browser.safebrowsing.phishing.enabled" = false;
            "dom.ipc.plugins.reportCrashURL" = false;
            "breakpad.reportURL" = "";
            "beacon.enabled" = false;
            "browser.search.geoip.url" = "";
            "browser.search.region" = "CA";
            "browser.search.suggest.enabled" = false;
            "browser.search.update" = false;
            "browser.selfsupport.url" = "";
            "extensions.getAddons.cache.enabled" = false;
            "extensions.pocket.enabled" = false;
            "geo.enabled" = false;
            "geo.wifi.uri" = false;
            "keyword.enabled" = false;
            "media.getusermedia.screensharing.enabled" = false;
            "media.video_stats.enabled" = false;
            "device.sensors.enabled" = false;
            "dom.battery.enabled" = false;
            "dom.enable_performance" = false;

            # concessions
            "network.dns.disablePrefetch" = false;
            "network.http.speculative-parallel-limit" = 8;
            "network.predictor.cleaned-up" = true;
            "network.predictor.enabled" = true;
            "network.prefetch-next" = true;
            "security.dialog_enable_delay" = 300;

            "dom.event.contextmenu.enabled" = false; # hm this is useful but sometimes I want it?

            "privacy.trackingprotection.enabled" = true;
            "privacy.trackingprotection.fingerprinting.enabled" = true;
            "privacy.trackingprotection.cryptomining.enabled" = true;
            "privacy.trackingprotection.introCount" = 20;
            "signon.rememberSignons" = false;
            "xpinstall.whitelist.required" = false;
            "xpinstall.signatures.required" = false;
            "general.smoothScroll" = false; # this might not be so bad but...
            "general.warnOnAboutConfig" = false;
          };
          containers.identities = [
            { id = 7; name = "Professional"; icon = "briefcase"; color = "red"; }
            { id = 8; name = "Shopping"; icon = "cart"; color = "pink"; }
            { id = 9; name = "Sensitive"; icon = "gift"; color = "orange"; }
            { id = 10; name = "Private"; icon = "fence"; color = "blue"; }
          ];
        };
      };
    };
    programs.firefox.tridactyl = let
      src = ./files/tridactyl/tridactylrc;
      xsel = "${pkgs.xsel}/bin/xsel";
      mpv = "${pkgs.mpv}/bin/mpv";
      urxvt = "${pkgs.rxvt-unicode-arc}/bin/urxvt";
      vim = "${config.programs.vim.package}/bin/vim";
      firefox = "${config.programs.firefox.packageWrapped}/bin/firefox";
    in {
      enable = true;
      sanitise = {
        local = true;
        sync = true;
      };
      themes = {
        custom = ''
          :root.TridactylThemeCustom {
              --tridactyl-hintspan-font-family: monospace, courier, sans-serif;
              --tridactyl-hintspan-font-size: 12px;
              --tridactyl-hintspan-fg: #fff;
              --tridactyl-hintspan-bg: #000088;
              --tridactyl-hintspan-border-color: #000;
              --tridactyl-hintspan-border-width: 1px;
              --tridactyl-hintspan-border-style: dashed;
              --tridactyl-hint-bg: #ffff99;
              --tridactyl-hint-outline: 1px dotted #000;
              --tridactyl-hint-active-bg: #00ff00;
              --tridactyl-hint-active-outline: 1px dotted #000;
          }

          :root.TridactylThemeCustom .TridactylHintElem {
              opacity: 0.3;
          }

          :root.TridactylThemeCustom span.TridactylHint {
              padding: 1px;
              margin-top: 8px;
              margin-left: -8px;
              opacity: 0.9;
              text-shadow: black -1px -1px 0px, black -1px 0px 0px, black -1px 1px 0px, black 1px -1px 0px, black 1px 0px 0px, black 1px 1px 0px, black 0px 1px 0px, black 0px -1px 0px !important;
          }
        '';
      };
      extraConfig = mkMerge [
        # colors halloween # oh god what
        # colors dark
        # colors shydactyl
        # colors greenmat
        "colors default"
        "colors custom"

        # these just modify userChrome.css, so do it ourselves instead
        # guiset_quiet gui none
        # guiset_quiet tabs always
        # guiset_quiet navbar always
        # guiset_quiet hoverlink right

        # kill all existing searchurls
        (mkBefore ''jsb Promise.all(Object.keys(tri.config.get("searchurls")).forEach(u => tri.config.set("searchurls", u, "")))'')
        "jsb localStorage.fixedamo = true"
      ];

      autocmd = {
        docStart = [
          { urlPattern = ''^https:\/\/www\.reddit\.com''; cmd = ''js tri.excmds.urlmodify("-t", "www", "old")''; }
        ];
      };

      exalias = {
        wq = "qall";

        # whee clipboard stuff
        fn_getsel = ''jsb tri.native.run("${xsel} -op").then(r => r.content)'';
        fn_getclip = ''jsb tri.native.run("${xsel} -ob").then(r => r.content)'';
        fn_setsel = ''jsb -p tri.native.run("${xsel} -ip", JS_ARG)'';
        fn_setclip = ''jsb -p tri.native.run("${xsel} -ib", JS_ARG)'';

        fn_noempty = "jsb -p return JS_ARG";
      };

      bindings = [
        { key = ";y"; cmd = ''composite hint -pipe a[href]:not([display="none"]):not([href=""]) href | fn_setsel''; }
        { key = ";Y"; cmd = ''composite hint -pipe a[href]:not([display="none"]):not([href=""]) href | fn_setclip''; }
        { key = ";m"; cmd = ''composite hint -pipe a[href]:not([display="none"]):not([href=""]) href | shellescape | exclaim_quiet ${mpv}''; }
        { key = "F"; cmd = ''composite hint -t -c a[href]:not([display="none"]) href''; }
        # mpv --ontop --keepaspect-window --profile=protocol.http

        { mode = "hint"; key = "j"; mods = ["alt"]; cmd = "hint.focusBottomHint"; }
        { mode = "hint"; key = "k"; mods = ["alt"]; cmd = "hint.focusTopHint"; }
        { mode = "hint"; key = "h"; mods = ["alt"]; cmd = "hint.focusLeftHint"; }
        { mode = "hint"; key = "l"; mods = ["alt"]; cmd = "hint.focusRightHint"; }

        # Fix hints on google search results
        { urlPattern = ''www\.google\.com''; key = "f"; cmd = "hint -Jc .rc>.r>a"; }
        { urlPattern = ''www\.google\.com''; key = "F"; cmd = "hint -Jtc .rc>.r>a"; }

        # Comment toggler for Reddit and Hacker News
        { urlPattern = ''reddit\.com''; key = ";c"; cmd = ''hint -c [class*="expand"],[class="togg"]''; }

        # GitHub pull request checkout command to clipboard
        { key = "ygp"; cmd = ''composite js /^https?:\/\/github\.com\/([.0-9a-zA-Z_-]*\/[.0-9a-zA-Z_-]*)\/pull\/([0-9]*)/.exec(document.location.href) | js -p `git fetch https://github.com/''${JS_ARG[1]}.git pull/''${JS_ARG[2]}/head:pull-''${JS_ARG[2]} && git checkout pull-''${JS_ARG[2]}` | fn_setsel''; }

        # Git{Hub,Lab} git clone via SSH yank (NOTE: for https just... copy the url!)
        { key = "ygc"; cmd = ''composite js "git clone " + document.location.href.replace(/https?:\/\//,"git@").replace("/",":").replace(/$/,".git") | fn_setsel''; }

        # Git add remote (what if you want name to be upstream or something different? can I prompt via fillcmdline..?)
        { key = "ygr"; cmd = ''composite js /^https?:\/\/(github\.com|gitlab\.com)\/([.0-9a-zA-Z_-]*)\/([.0-9a-zA-Z_-]*)/.exec(document.location.href) | js -p `git remote add ''${JS_ARG[3]} https://''${JS_ARG[1]/''${JS_ARG[2]}/''${JS_ARG[3]}.git && git fetch ''${JS_ARG[3]}` | fn_setsel''; }

        # I like wikiwand but I don't like the way it changes URLs
        { urlPattern = ''wikiwand\.com''; key = "yy"; cmd = ''composite js document.location.href.replace("wikiwand.com/en","wikipedia.org/wiki") | fn_setsel''; }

        # attempt to maintain one tab per window:
        # bind F hint -w
        # bind T current_url winopen
        # bind t fillcmdline winopen

        { key = "r"; cmd = "reload"; }
        { key = "R"; cmd = "reloadhard"; }
        { key = "d"; cmd = "tabclose"; }

        { key = "``"; cmd = "tab #"; }

        { key = "j"; cmd = "scrollline 6"; }
        { key = "k"; cmd = "scrollline -6"; }

        { mode = ["normal" "input" "insert"]; key = "h"; mods = ["ctrl"]; cmd = "tabprev"; }
        { mode = ["normal" "input" "insert"]; key = "l"; mods = ["ctrl"]; cmd = "tabnext"; }
        # TODO: consider C-jk instead of C-hl?
        { mode = ["normal" "input" "insert"]; key = "k"; mods = ["ctrl"]; cmd = "tabmove -1"; }
        { mode = ["normal" "input" "insert"]; key = "j"; mods = ["ctrl"]; cmd = "tabmove +1"; }
        { key = "<Space>"; cmd = "scrollpage 0.75"; }
        { mode = "ex"; key = "a"; mods = ["ctrl"]; cmd = null; }

        # Make gu take you back to subreddit from comments
        { urlPattern = ''reddit\.com''; key = "gu"; cmd = "urlparent 3"; }

        # inpage find (not recommended for actual use)
        { key = "/"; mods = ["ctrl"]; cmd = "fillcmdline find"; }
        { key = "?"; cmd = "fillcmdline find -?"; }
        { key = "n"; cmd = "findnext 1"; }
        { key = "N"; cmd = "findnext -1"; }
        { key = ",<Space>"; cmd = "nohlsearch"; }

        { key = "gi"; cmd = "focusinput -l"; } # this should be 0 but it never seems to focus anything visible or useful?
        { key = "i"; cmd = "focusinput -l"; }
        { key = "I"; cmd = "mode ignore"; }
        { mode = "ignore"; key = "<Escape>"; cmd = "composite mode normal ; hidecmdline"; }

        { key = "<Insert>"; mods = ["shift"]; cmd = "composite fn_getsel | fillcmdline_notrail open"; }
        { key = "<Insert>"; mods = ["shift" "alt"]; cmd = "composite fn_getclip | fillcmdline_notrail open"; }
        { key = "C"; mods = ["shift" "alt"]; cmd = "composite fn_getsel | fn_setclip"; }
        { mode = ["ex" "input" "insert"]; key = "<Insert>"; mods = ["shift"]; cmd = "composite fn_getsel | text.insert_text"; }
        { mode = ["ex" "input" "insert"]; key = "<Insert>"; mods = ["shift" "alt"]; cmd = "composite fn_getclip | text.insert_text"; }
        { mode = ["ex" "input" "insert"]; key = "V"; mods = ["shift" "alt"]; cmd = "composite fn_getclip | text.insert_text"; }
        { mode = ["ex" "input" "insert"]; key = "C"; mods = ["shift" "alt"]; cmd = "composite fn_getsel | fn_setclip"; }

        { mode = ["insert" "input"]; key = "e"; mods = ["ctrl"]; cmd = "editor"; }
      ];

      settings = {
        allowautofocus = false;

        browser = firefox;

        editorcmd = ''${urxvt} -e ${vim} %f -c "normal %lG%cl"'';

        nag = false;
        leavegithubalone = false;
        newtabfocus = "page";
        # until empty newtab focus works...
        newtab = "http://blank.org";
        tabopencontaineraware = false;
        #storageloc = "local";
        storageloc = "sync";
        hintuppercase = false;
        hintchars = "fdsqjklmrezauiopwxcvghtybn";
        #hintfiltermode = "vimperator-reflow";
        #hintnames = "numeric";
        modeindicator = true;
        modeindicatorshowkeys = true;
        autocontainmode = "relaxed";

        # Make Tridactyl work on more sites at the expense of some security
        csp = "clobber";

        searchengine = "g";
        "searchurls.g" = "https://encrypted.google.com/search?q=%s";
        "searchurls.gh" = "https://github.com/search?q=%s";
        "searchurls.ghc" = "https://github.com/%s1/search?q=%s2";
        "searchurls.ghf" = "https://github.com/%s1/search?q=filename%3a%s2";
        "searchurls.ghp" = "https://github.com/%s1/pulls?q=%s2";
        "searchurls.ghi" = "https://github.com/%s1/issues?q=is%3aissue+%s2";
        "searchurls.gha" = "https://github.com/%s1/issues?q=%s2";
        "searchurls.w" = "https://en.wikipedia.org/wiki/Special:Search?search=%s";
        "searchurls.ddg" = "https://duckduckgo.com/?q=%s";
        "searchurls.r" = "https://reddit.com/r/%s";
        "searchurls.rs" = "https://doc.rust-lang.org/std/index.html?search=%s";
        "searchurls.crates" = "https://lib.rs/search?q=%s";
        "searchurls.docs" = "https://docs.rs/%s/*";
        "searchurls.aur" = "https://aur.archlinux.org/packages/?K=%s";
        "searchurls.yt" = "https://www.youtube.com/results?search_query=%s";
        "searchurls.az" = "https://www.amazon.ca/s/ref=nb_sb_noss?url=search-alias%3Daps&field-keywords=%s";

        putfrom = "selection";
        # set yankto selection
        yankto = "both";
        externalclipboardcmd = xsel;
      };
      urlSettings = {
        allowautofocus = {
          "play\\.rust-lang\\.org" = { value = true; };
          "typescriptlang\\.org/play" = { value = true; };
        };
      };
    };
    programs.mpv = {
      enable = true;
      config = {
        hwdec = mkDefault "auto";

        vo = mkDefault "gpu";
        opengl-waitvsync = "yes";

        keep-open = "yes";

        cache-secs = 10 * 60 * 60; # 10 hours, the default - in practice this is capped by demuxer-max-bytes
      };
    };
    home.symlink = {
      ".local/share/mozilla/native-messaging-hosts".target = "${config.programs.firefox.packageWrapped}/lib/mozilla/native-messaging-hosts";
      ".mozilla" = {
        target = "${config.xdg.dataHome}/mozilla";
        create = true;
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
        application/pdf=evince.desktop
        text/plain=vim.desktop
        application/xml=vim.desktop
      '';
      "luakit" = {
        source = ./files/luakit;
        recursive = true;
      };
      "luakit/rc/nix.lua".source = pkgs.substituteAll {
        src = ./files/luakit-nix.lua;
        pass = pkgs.pass-arc;
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
    home.shell.aliases = {
      konawall = "systemctl --user restart konawall.service";
      oryx = "nix run nixpkgs.google-chrome -c google-chrome-stable https://configure.ergodox-ez.com/train";
    };

    xsession = {
      enable = true;
      profileExtra = ''
        export XDG_CURRENT_DESKTOP=i3
        ${pkgs.xorg.setxkbmap}/bin/setxkbmap -option numpad:microsoft
        ${pkgs.xorg.setxkbmap}/bin/setxkbmap -option numpad:shift3
        ${pkgs.xorg.setxkbmap}/bin/setxkbmap -option ctrl:nocaps

        ${pkgs.xcompmgr}/bin/xcompmgr &
        ${pkgs.rxvt-unicode-arc}/bin/urxvtd &

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
