{ pkgs, lib, config, ... }: with lib; let
  homeConfig = config;
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
      passwordCommand = mkIf (config.password.entry != null && homeConfig.programs.bitw.enable) (mkDefault
        "${homeConfig.programs.bitw.package}/bin/bitw get -f ${config.password.field} ${config.password.entry}"
      );
      imapnotify = {
        onNotify = mkMerge [
          (mkIf config.lieer.enable "${homeConfig.programs.lieer.package}/bin/gmi pull -C ${homeConfig.accounts.email.maildirBasePath}/${config.maildir.path}")
          (mkIf config.mbsync.enable "${homeConfig.programs.mbsync.package}/bin/mbsync ${name}")
        ];
        onNotifyPost = mkMerge [
          (mkIf config.notmuch.enable "${homeConfig.programs.notmuch.package}/bin/notmuch --config=${homeConfig.home.sessionVariables.NOTMUCH_CONFIG} new")
        ];
      };
      lieer = {
        settings = {
          # a single message may be cc'd to multiple accounts, do not allow any of the tags to sync back
          ignore_tags = mapAttrsToList (_: acc: acc.notmuch.tag) (
            filterAttrs (_: acc: acc.notmuch.enable && acc.notmuch.tag != null) homeConfig.accounts.email.accounts
          ) ++ homeConfig.programs.notmuch.new.tags ++ [ "deleted" ];
          translation_list_overlay = concatLists (mapAttrsToList (k: v: [ k v ]) config.lieer.remoteTranslations);
        };
      };
      offlineimap = {
        postSyncHookCommand = mkIf config.notmuch.enable "${homeConfig.programs.notmuch.package}/bin/notmuch --config=${homeConfig.home.sessionVariables.NOTMUCH_CONFIG} new";
      };
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
  config = {
    home.activation = mkIf config.programs.lieer.enable (mapAttrs' (name: acc: nameValuePair "lieer-init-${name}" (lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      LIEER_MAILDIR=${config.accounts.email.maildirBasePath}/${acc.maildir.path}
      if [[ ! -e $LIEER_MAILDIR/mail ]]; then
        $DRY_RUN_CMD ${config.programs.lieer.package}/bin/gmi init \
          -C "$LIEER_MAILDIR" \
          --no-auth \
          ${acc.address}
        fi
    '')) (filterAttrs (_: acc: acc.lieer.enable) config.accounts.email.accounts));
    # TODO: ${if acc.lieer.credentialsPath != null then "-c ${acc.lieer.credentialsPath}" else "--no-auth"}
    services.offlineimap.enable = false; #config.programs.offlineimap.enable;
    services.lieer.enable = config.accounts.email.enableSync;
    services.imapnotify.enable = config.accounts.email.enableSync;
    programs.lieer.enable = config.accounts.email.enableSync;
    programs.notmuch = let
      notmuch = config.programs.notmuch;
      accountsWithTags = filterAttrs (_: acc: acc.notmuch.enable && acc.notmuch.tag != null) config.accounts.email.accounts;
    in {
      hooks.new = {
        tagCommands = mkMerge [
          (mkBefore (mapAttrsToList (name: acc: ''
            tag -n 'path:${acc.maildir.path}/**' '+${acc.notmuch.tag}'
          '') accountsWithTags))
          (mkAfter [
            ''tag "path:sent/**" +sent'' # special msmtp sent folder?
          ])
        ];
      };
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
  };
}
