{ pkgs, lib, config, ... }: with lib; let
  gmailIdleFolders = [ "INBOX" "[Gmail]/Starred" ];
  gmailIdleIgnore = [ "[Gmail]/Important" "[Gmail]/Drafts" ];
  listToPython = list: "[" + concatMapStringsSep ", " (f: "'${f}'") list + "]";
  emailModule = { config, name, ... }: {
    config = {
      imapnotify = {
        enable = mkDefault true;
        boxes = mkIf (config.flavor == "gmail.com") gmailIdleFolders;
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
          ignore_remote_labels = [
            "CATEGORY_FORUMS" "CATEGORY_PROMOTIONS" "CATEGORY_UPDATES" "CATEGORY_SOCIAL" "CATEGORY_PERSONAL"
            "IMPORTANT"
          ];
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
    accounts.email = {
      accounts = mkOption {
        type = with types; attrsOf (submodule emailModule);
      };
    };
  };
  config = {
    accounts.email = {
      maildirBasePath = "${config.xdg.cacheHome}/mail";
      accounts.arcnmx = rec {
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
      new.tags = [ "new" ];
      search.excludeTags = [ "deleted" "trash" "spam" "junk" "draft" "twitter" ];
      hooks.new = {
        notify = mkDefault (config.services.dunst.enable || config.services.kdeconnect.enable);
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
  };
}
