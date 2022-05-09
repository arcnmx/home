{ pkgs, lib, config, ... }: with lib; let
  homeConfig = config;
  gmailIdleFolders = [ "INBOX" "[Gmail]/Starred" ];
  gmailIdleIgnore = [ "[Gmail]/Important" "[Gmail]/Drafts" ];
  listToPython = list: "[" + concatMapStringsSep ", " (f: "'${f}'") list + "]";
  emailModule = { config, name, ... }: {
    options = {
      password = {
        entry = mkOption {
          type = with types; nullOr str;
          default = null;
        };
        field = mkOption {
          type = types.str;
          default = "password";
        };
      };
      lieer = {
        credentialsPath = mkOption {
          type = with types; nullOr path;
          default = null;
        };
        remoteTranslations = mkOption {
          type = with types; attrsOf str;
          default = { };
        };
      };
      notmuch.tag = mkOption {
        type = with types; nullOr str;
        default = null; # name
      };
    };
    config = {
      passwordCommand = mkIf (config.password.entry != null) (mkDefault
        "${homeConfig.home.profileSettings.bitw}/bin/bitw get -f ${config.password.field} ${config.password.entry}"
      );
      imapnotify = {
        enable = mkDefault true;
        boxes = mkIf (config.flavor == "gmail.com") gmailIdleFolders;
        onNotify = mkMerge [
          (mkIf config.lieer.enable "${homeConfig.programs.lieer.package}/bin/gmi pull -C ${homeConfig.accounts.email.maildirBasePath}/${config.maildir.path}")
          (mkIf config.mbsync.enable "${homeConfig.programs.mbsync.package}/bin/mbsync ${name}")
        ];
        onNotifyPost = mkMerge [
          (mkIf config.notmuch.enable "${homeConfig.programs.notmuch.package}/bin/notmuch --config=${homeConfig.home.sessionVariables.NOTMUCH_CONFIG} new")
        ];
      };
      lieer = {
        enable = mkIf (config.flavor == "gmail.com") (mkDefault true);
        sync = {
          enable = mkDefault true;
          frequency = "*:0/30"; # every 30 minutes
        };
        remoteTranslations = {
          Notifications = "notif";
          Work = "work";
          Later = "later";
        };
        settings = {
          replace_slash_with_dot = mkDefault true;
          # a single message may be cc'd to multiple accounts, do not allow any of the tags to sync back
          ignore_tags = mapAttrsToList (_: acc: acc.notmuch.tag) (
            filterAttrs (_: acc: acc.notmuch.enable && acc.notmuch.tag != null) homeConfig.accounts.email.accounts
          ) ++ homeConfig.programs.notmuch.new.tags ++ [ "deleted" ];
          ignore_remote_labels = [
            "CATEGORY_FORUMS" "CATEGORY_PROMOTIONS" "CATEGORY_UPDATES" "CATEGORY_SOCIAL" "CATEGORY_PERSONAL"
            "IMPORTANT"
          ];
          translation_list_overlay = concatLists (mapAttrsToList (k: v: [ k v ]) config.lieer.remoteTranslations);
        };
      };
      offlineimap = {
        #enable = mkDefault true;
        extraConfig = {
          account = {
            autorefresh = 5;
            quick = 20;
            holdconnectionopen = "yes";
          };
          local = {
            nametrans = ''lambda foldername: local_nametrans("${name}", foldername, foldername)'';
            sync_deletes = false;
          };
          remote = {
            nametrans = ''lambda foldername: remote_nametrans("${name}", foldername, gmail_nametrans(foldername))'';
            folderfilter = ''lambda foldername: foldername not in ${listToPython gmailIdleIgnore}'';
            createfolders = "False";
            ssl_version = "tls1_2";
            idlefolders = listToPython gmailIdleFolders;
            maxconnections = 3;
          };
        };
        postSyncHookCommand = "${homeConfig.programs.notmuch.package}/bin/notmuch --config=${homeConfig.home.sessionVariables.NOTMUCH_CONFIG} new";
      };
      mbsync = {
        enable = mkIf (config.flavor != "gmail.com") (mkDefault true);
      };
      msmtp.enable = mkDefault true;
      notmuch.enable = mkDefault true;
    };
  };
in {
  options = {
    programs.notmuch = {
      package = mkOption {
        type = types.package;
        default = pkgs.notmuch;
        defaultText = "pkgs.notmuch";
      };
      hooks.new = {
        notify = mkEnableOption "email notifications";
        tagCommands = mkOption {
          type = with types; listOf str;
          default = [ ];
        };
      };
    };
    accounts.email = {
      enableSync = mkEnableOption "email";
      accounts = mkOption {
        type = with types; attrsOf (submodule emailModule);
      };
    };
  };
  config = mkMerge [ {
    accounts.email = {
      maildirBasePath = "${config.xdg.cacheHome}/mail";
      accounts.arcnmx = mkIf (config.home.username != "root") rec {
        primary = true;
        realName = "arc";
        flavor = "gmail.com";
        password.entry = "arcnmx/google";
        notmuch.tag = "arcnmx";
        lieer.remoteTranslations = {
          "Notifications/Twitch" = "twitch";
          "Notifications/CI" = "ci";
          "Twitter" = "twitter";
        };
        address = realName + "nmx@" + flavor;
      };
    };
    programs.lieer.package = pkgs.lieer-develop;
    home.activation = mkIf config.programs.lieer.enable (mapAttrs' (name: acc: nameValuePair "lieer-init-${name}" (lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      LIEER_MAILDIR=${config.accounts.email.maildirBasePath}/${acc.maildir.path}
      if [[ ! -e $LIEER_MAILDIR/mail ]]; then
        $DRY_RUN_CMD ${config.programs.lieer.package}/bin/gmi init \
          -C "$LIEER_MAILDIR" \
          --no-auth \
          ${acc.address}
        fi
    '')) (filterAttrs (_: acc: acc.lieer.enable) config.accounts.email.accounts));
  } (mkIf config.home.profiles.personal {
    # TODO: ${if acc.lieer.credentialsPath != null then "-c ${acc.lieer.credentialsPath}" else "--no-auth"}
    services.offlineimap.enable = false; #config.programs.offlineimap.enable;
    services.lieer.enable = config.accounts.email.enableSync;
    services.imapnotify.enable = config.accounts.email.enableSync;
    programs.lieer.enable = config.accounts.email.enableSync;
    programs.msmtp.enable = true;
    programs.offlineimap = {
      extraConfig.general = {
        maxsyncaccounts = 5;
        fsync = false;
      };
      pythonFile = let
        foldermapdir = "${config.xdg.dataHome}/offlineimap/folder_map";
      in replaceStrings [ "@foldermapdir@" ] [ foldermapdir ] (readFile ./files/offlineimap.py);
    };
    programs.notmuch = let
      notmuch = config.programs.notmuch;
      accountsWithTags = filterAttrs (_: acc: acc.notmuch.enable && acc.notmuch.tag != null) config.accounts.email.accounts;
    in {
      enable = mkDefault true;
      #package = mkDefault pkgs.notmuch-arc;
      new.tags = [ "new" ];
      search.excludeTags = [ "deleted" "trash" "spam" "junk" "draft" "twitter" ];
      hooks.new = {
        notify = mkDefault true;
        tagCommands = mkMerge [
          (mkBefore (mapAttrsToList (name: acc: ''
            tag -n 'path:${acc.maildir.path}/**' '+${acc.notmuch.tag}'
          '') accountsWithTags))
          (mkAfter [
            ''tag "path:sent/**" +sent'' # special msmtp sent folder?
          ])
        ];
      };
      hooks.postNew = mkMerge [
        (mkBefore ''
          TAGS_ACCOUNT=(${escapeShellArgs (mapAttrsToList (_: acc: acc.notmuch.tag) accountsWithTags)})
          TAGS_NEW=(${escapeShellArgs notmuch.new.tags})
          TAGS_EXCLUDE=(${escapeShellArgs notmuch.search.excludeTags})
          TAGS_NEW_HIDE=(flagged inbox sent notif)
          source ${./files/notmuch-post-new-header}
        '') (mkIf (notmuch.hooks.new.tagCommands != [ ]) ''
          {
            ${concatStringsSep "\n" notmuch.hooks.new.tagCommands}
          } | notmuch tag --batch
        '') (mkIf notmuch.hooks.new.notify (mkAfter ''
          source ${pkgs.substituteAll {
            src = ./files/notmuch-post-new-notify;
            inherit (pkgs) libnotify jq gnused coreutils;
          }}
        '')) (mkOrder 2000 ''
          notmuch tag -new -- tag:new
        '')
      ];
    };
    systemd.user.timers = mkIf config.services.lieer.enable (
      mapAttrs' (_: acc: nameValuePair "lieer-${acc.name}" {
        Timer.OnStartupSec = "30s";
      }) (filterAttrs (_: acc: acc.lieer.enable && acc.lieer.sync.enable) config.accounts.email.accounts)

    );
    systemd.user.services = mkMerge [ (mkIf config.services.lieer.enable (
      mapAttrs' (_: acc: nameValuePair "lieer-${acc.name}" {
        # override because the home-manager service does not run "notmuch new"
        Service.ExecStart = mkForce "${pkgs.writeShellScript "lieer-${acc.name}-sync" ''
          set -eu
          ${config.programs.lieer.package}/bin/gmi sync
          if ! ${config.programs.notmuch.package}/bin/notmuch new; then
            echo "notmuch new failed" >&2
          fi
        ''}";
      }) (filterAttrs (_: acc: acc.lieer.enable && acc.lieer.sync.enable) config.accounts.email.accounts)
    )) {
      offlineimap = mkIf config.services.offlineimap.enable {
        Service.Nice = "10"; # offlineimap is surprisingly wasteful :(
      };
    } ];
  }) ];
}
