{ config, pkgs, lib, ... } @ args: with lib; let
  inherit (config.lib.file) mkOutOfStoreSymlink;
  firefoxFiles = let
    pathConds = {
      "extensions/{ec8030f7-c20a-464f-9b0e-13a3a9e97384}" = any (profile:
        profile.extensions != []
      ) (attrValues config.programs.firefox.profiles);
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
    ./tridactyl.nix
  ];

  programs.firefox = {
    enable = true;
    packageUnwrapped = pkgs.firefox-bin-unwrapped;
    wrapperConfig = {
      extraPolicies = {
        DisableAppUpdate = true;
      };
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
          "browser.tabs.remote.separatedMozillaDomains" = "";
          "browser.tabs.remote.separatePrivilegedContentProcess" = false;
          "browser.tabs.remote.separatePrivilegedMozillaWebContentProcess" = false;
          "browser.tabs.unloadOnLowMemory" = true;
          "browser.tabs.closeWindowWithLastTab" = false;
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

          "dom.event.contextmenu.enabled" = true; # learn to shift+right-click instead

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
        userChrome = builtins.readFile ./tst.css;
      };
    };
  };
  home = mkIf config.programs.firefox.enable {
    file = firefoxFiles;
    sessionVariables = {
      # firefox
      MOZ_WEBRENDER = "1";
      MOZ_USE_XINPUT2 = "1";
    };
    shell = {
      functions = {
        firefox = ''
          ( # subshell important!
            echo 200 > /proc/self/oom_score_adj
            exec ${config.programs.firefox.package}/bin/firefox "$@"
          )
        '';
      };
    };
  };
  xdg = mkIf config.programs.firefox.enable {
    dataFile = mkIf config.programs.firefox.enable {
      "mozilla/native-messaging-hosts".source = mkOutOfStoreSymlink "${config.programs.firefox.package}/lib/mozilla/native-messaging-hosts";
    };
    configFile = mkIf config.programs.firefox.enable {
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
  };
}
