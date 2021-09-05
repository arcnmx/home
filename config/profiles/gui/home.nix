{ meta, base16, config, pkgs, lib, ... } @ args: with lib; let
  inherit (config.lib.file) mkOutOfStoreSymlink;
  mpv = "${config.programs.mpv.finalPackage}/bin/mpv";
  firefoxFiles = let
    pathConds = {
      "extensions/{ec8030f7-c20a-464f-9b0e-13a3a9e97384}" = config.programs.firefox.extensions != [];
      "profiles.ini" = config.programs.firefox.profiles != {};
    } // foldAttrList (mapAttrsToList (_: profile: {
      "${profile.path}/.keep" = true;
      "${profile.path}/chrome/userChrome.css" = profile.userChrome != "";
      "${profile.path}/user.js" = profile.settings != {} || profile.extraConfig != "";
      "${profile.path}/containers.json" = profile.containers.identities != [];
    }) config.programs.firefox.profiles);
    paths = mapAttrs' (k: cond: nameValuePair ".mozilla/firefox/${k}" (mkIf cond {
      target = "${config.xdg.dataHome}/mozilla/firefox/${k}";
    })) pathConds;
  in {
    ".mozilla".source = mkOutOfStoreSymlink "${config.xdg.dataHome}/mozilla";
  } // paths;
in {
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
    home.file = mkMerge [ {
      ".xinitrc" = {
        executable = true;
        text = ''
          #!${pkgs.bash}/bin/bash
          ${pkgs.xorg.xrdb}/bin/xrdb -merge ~/.Xresources
          . ~/.xsession
        '';
      };
    } (mkIf config.programs.firefox.enable firefoxFiles) ];
    home.shell = {
      functions = {
        mpa = ''
          PULSE_PROP="media.role=music" ${mpv} --no-video "$@"
        '';
        mpv = ''
          PULSE_PROP="media.role=video" ${mpv} "$@"
        '';
        discord = ''
          PULSE_PROP="media.role=phone" nix run nixpkgs.discord -c Discord "$@"
        '';
        ffr = ''
          nix run nixpkgs.flashplayer-standalone -c flashplayer http://www.flashflashrevolution.com/~velocity/R^3.swf
        '';
        monstercatfm = ''
          mplay ytdl://http://twitch.tv/monstercat
        '';
        imv = ''
          command imv "$@" &
        '';
      };
    };
    programs.zsh.loginExtra = ''
      if [[ -z "''${TMUX-}" && -z "''${DISPLAY-}" && "''${XDG_VTNR-}" = 1 && $(${pkgs.coreutils}/bin/id -u) != 0 ]]; then
        ${pkgs.xorg.xinit}/bin/startx
      fi
    '';
    home.packages = with pkgs; [
      config.services.konawall.konashow
      ffmpeg
      youtube-dl
      scrot
      xsel
      xorg.xinit
      xdg_utils-mimi
      arc.packages.personal.emxc
      rxvt-unicode-arc
      mumble-develop
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
    services.picom = {
      enable = mkDefault true;
      experimentalBackends = mkDefault true;
      package = mkDefault pkgs.picom-next;
      opacityRule = [
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
    programs.firefox = {
      enable = true;
      packageUnwrapped = pkgs.firefox-unwrapped;
      wrapperConfig = {
        extraNativeMessagingHosts = with pkgs; [
          tridactyl-native
        ] ++ optional config.programs.buku.enable bukubrow;
      };
      profiles = {
        arc = {
          id = 0;
          isDefault = true;
          settings = {
            "browser.download.dir" = "${config.xdg.userDirs.absolute.download}";
            ${if config.home.hostName != null then "services.sync.client.name" else null} = config.home.hostName;
            "services.sync.engine.prefs" = false;
            "services.sync.engine.prefs.modified" = false;
            "services.sync.engine.passwords" = false;
            "services.sync.declinedEngines" = "passwords,adblockplus,prefs";
            "media.eme.enabled" = true; # whee drm
            "gfx.webrender.all.qualified" = true;
            "gfx.webrender.all" = true;
            "layers.acceleration.force-enabled" = true;
            "gfx.canvas.azure.accelerated" = true;
            "browser.ctrlTab.recentlyUsedOrder" = false;
            "privacy.resistFingerprinting.block_mozAddonManager" = true;
            "extensions.webextensions.restrictedDomains" = "";
            "tridactyl.unfixedamo" = true; # stop trying to change this file :(
            "tridactyl.unfixedamo_removed" = true; # wh-what happened this time?
            "browser.shell.checkDefaultBrowser" = false;
            "spellchecker.dictionary" = "en-CA";
            "ui.context_menus.after_mouseup" = true;
            "browser.warnOnQuit" = false;
            "browser.quitShortcut.disabled" = true;
            "browser.startup.homepage" = "about:blank";
            "browser.contentblocking.category" = "strict";
            "browser.discovery.enabled" = false;
            "browser.tabs.multiselect" = true;
            "browser.tabs.unloadOnLowMemory" = true;
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
            "extensions.pocket.enabled" = true;
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
      urxvt = "${pkgs.rxvt-unicode-arc}/bin/urxvt";
      vim = "${config.programs.vim.package}/bin/vim";
      firefox = "${config.programs.firefox.package}/bin/firefox";
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
        tabEnter = [
          { urlPattern = ".*"; cmd = "unfocus"; } # alternative to `allowautofocus=false`
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
        { mode = ["normal" "input" "insert"]; key = "J"; mods = ["ctrl"]; cmd = "tabnext"; }
        { mode = ["normal" "input" "insert"]; key = "K"; mods = ["ctrl"]; cmd = "tabprev"; }
        # TODO: consider C-jk instead of C-hl?
        { mode = ["normal" "input" "insert"]; key = "k"; mods = ["ctrl"]; cmd = "tabmove -1"; }
        { mode = ["normal" "input" "insert"]; key = "j"; mods = ["ctrl"]; cmd = "tabmove +1"; }
        { key = "<Space>"; cmd = "scrollpage 0.75"; }
        { key = "f"; mods = ["ctrl"]; cmd = null; }
        { key = "b"; mods = ["ctrl"]; cmd = null; }
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
        { mode = "ignore"; key = "<Escape>"; mods = ["shift"]; cmd = "composite mode normal ; hidecmdline"; }

        { key = "<Insert>"; mods = ["shift"]; cmd = "composite fn_getsel | fillcmdline_notrail open"; }
        { key = "<Insert>"; mods = ["shift" "alt"]; cmd = "composite fn_getclip | fillcmdline_notrail open"; }
        { key = "C"; mods = ["shift" "alt"]; cmd = "composite fn_getsel | fn_setclip"; }
        { mode = ["ex" "input" "insert"]; key = "<Insert>"; mods = ["shift"]; cmd = "composite fn_getsel | text.insert_text"; }
        { mode = ["ex" "input" "insert"]; key = "<Insert>"; mods = ["shift" "alt"]; cmd = "composite fn_getclip | text.insert_text"; }
        { mode = ["ex" "input" "insert"]; key = "V"; mods = ["shift" "alt"]; cmd = "composite fn_getclip | text.insert_text"; }
        { mode = ["ex" "input" "insert"]; key = "C"; mods = ["shift" "alt"]; cmd = "composite fn_getsel | fn_setclip"; }

        { mode = ["insert" "input"]; key = "e"; mods = ["ctrl"]; cmd = "editor"; }

        { key = "<F1>"; cmd = null; }
      ];

      settings = {
        #allowautofocus = false;

        browser = firefox;

        editorcmd = ''${urxvt} -e ${vim} %f -c "normal %lG%cl"'';

        nag = false;
        leavegithubalone = false;
        newtabfocus = "page";
        # until empty newtab focus works...
        newtab = "http://blank.org";
        tabopencontaineraware = false;
        #storageloc = "local";
        #storageloc = "sync";
        hintuppercase = false;
        hintchars = "fdsqjklmrezauiopwxcvghtybn";
        #hintfiltermode = "vimperator-reflow";
        #hintnames = "numeric";
        modeindicator = true;
        modeindicatorshowkeys = true;
        autocontainmode = "relaxed";

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
        "searchurls.docs" = "https://docs.rs/%s1/*/?search=%s2";
        "searchurls.nixos" = "https://search.nixos.org/options?channel=unstable&from=0&size=1000&sort=alpha_asc&query=%s";
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
      scripts = with pkgs.mpvScripts; [
        sponsorblock mpris paused
      ];
      config = {
        input-default-bindings = false;

        hwdec = mkDefault "auto";

        vo = mkDefault "gpu";
        opengl-waitvsync = true;

        keep-open = true;

        volume-max = 200;
        osd-scale-by-window = false;
        osd-font-size = config.lib.gui.fontSize 26; # pixels at 720 window height, then scaled to real size
        osd-bar-h = 2.5; # 3.125 default
        osd-border-size = 2; # font border pixels, default 3
        term-osd-bar = true;
        script-opts = concatStringsSep "," (mapAttrsToList (k: v: "${k}=${toString v}") {
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
          "`" = "cycle mute";
          "SPACE" = "cycle pause";
          "w" = "screenshot";
          "W" = "screenshot video";
          "Ctrl+w" = "screenshot window";
          "Ctrl+W" = "screenshot each-frame";
          "o" = "show-progress";
          "O" = "script-message show_osc_dur 5";
          "F1" = "cycle sub";
          "F2" = "cycle audio";
          "Ctrl+p" = "cycle video";
          "L" = "add volume 2";
          "H" = "add volume -2";
          "Alt+H" = "add audio-delay -0.100";
          "Alt+L" = "add audio-delay 0.100";
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
          "m" = "cycle mute";
          "Ctrl+r" = "loadfile \${path}";
          "Ctrl+R" = "video-reload";
          "d" = "drop-buffers";
          "Ctrl+d" = "quit";
        };
        common = {
          "Ctrl+0" = "set speed 1.0";
          "Ctrl+=" = "multiply speed 1.1";
          "Ctrl+-" = "multiply speed 1/1.1";
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
          "MBTN_RIGHT" = vim."SPACE";
          "m" = vim."`";
          "WHEEL_UP" = vim."L";
          "WHEEL_DOWN" = vim."H";
        };
      in vim // common // optionalAttrs false directional;
    };
    programs.syncplay = {
      enable = true;
      username = "arc";
      defaultRoom = "lounge";
      gui = false;
      trustedDomains = [ "youtube.com" "youtu.be" "twitch.tv" "soundcloud.com" ];
      config = {
        client_settings = {
          autoplayrequiresamefiles = false;
          readyatstart = true;
          pauseonleave = false;
          rewindondesync = false;
          rewindthreshold = 6.0;
          fastforwardthreshold = 6.0;
          unpauseaction = "Always";
        };
        gui = {
          #autosavejoinstolist = false;
          showdurationnotification = false;
          chatoutputrelativefontsize = config.lib.gui.fontSize 13.0;
        };
      };
    };
    programs.imv = {
      enable = true;
      config = {
        scaling_mode = "shrink";
      };
      configContent.binds = {
        "<Ctrl+0>" = "zoom actual";
        "<Ctrl+minus>" = "zoom -10";
        "<Ctrl+equal>" = "zoom 10";
        "<Ctrl+h>" = "prev";
        "<Ctrl+l>" = "next";
        "O" = "overlay";
      };
    };
    services.playerctld.enable = true;
    xdg.dataFile = {
      "mozilla/native-messaging-hosts".source = mkOutOfStoreSymlink "${config.programs.firefox.package}/lib/mozilla/native-messaging-hosts";
    };
    xdg.configFile = {
      "mimeapps.list".text = ''
        [Default Applications]
        text/html=firefox.desktop
        x-scheme-handler/http=firefox.desktop
        x-scheme-handler/https=firefox.desktop
        image/jpeg=feh.desktop
        image/png=feh.desktop
        image/gif=feh.desktop
        application/pdf=evince.desktop
        text/plain=vim.desktop
        application/xml=vim.desktop
      '';
    };

    services.gpg-agent.pinentryFlavor = "gtk2";
    services.redshift = {
      enable = mkIf config.home.profiles.trusted true;
      tray = false;
    };
    services.konawall = {
      enable = true;
      interval = "20m";
    };
    home.shell.aliases = {
      konawall = "systemctl --user restart konawall.service";
      chrome = "nix run nixpkgs.google-chrome -c google-chrome-stable";
      oryx = "chrome https://configure.ergodox-ez.com/train";
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

        export LESS=''${LESS//F}
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
