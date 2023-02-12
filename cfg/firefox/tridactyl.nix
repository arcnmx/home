{ config, pkgs, lib, ... } @ args: with lib; {
  programs.firefox.tridactyl = let
    xsel = "${pkgs.xsel}/bin/xsel";
    urxvt = "${pkgs.rxvt-unicode-arc}/bin/urxvt";
    vim = config.home.sessionVariables.EDITOR;
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
            --tridactyl-hintspan-font-size: 8pt;
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
      { key = ";m"; cmd = ''composite hint -pipe a[href]:not([display="none"]):not([href=""]) href | shellescape | exclaim_quiet ${config.programs.mpv.finalPackage}/bin/mpv''; }
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

      { key = "`"; cmd = null; } # remove default binding: `gobble 1 markjump`
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

      editorcmd = "${urxvt} -e zsh -ic '${vim} %f \"+normal!%lG%c|\"'";

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
      "searchurls.ghc" = "https://github.com/%s1/%s2/search?q=%s3";
      "searchurls.ghf" = "https://github.com/%s1/%s2/search?q=filename%3a%s3";
      "searchurls.ghp" = "https://github.com/%s1/%s2/pulls?q=%s3";
      "searchurls.ghi" = "https://github.com/%s1/%s2/issues?q=is%3aissue+%s3";
      "searchurls.gha" = "https://github.com/%s1/%s2/issues?q=%s3";
      "searchurls.w" = "https://en.wikipedia.org/wiki/Special:Search?search=%s";
      "searchurls.ddg" = "https://duckduckgo.com/?q=%s";
      "searchurls.r" = "https://reddit.com/r/%s";
      "searchurls.rs" = "https://doc.rust-lang.org/std/index.html?search=%s";
      "searchurls.crates" = "https://lib.rs/search?q=%s";
      "searchurls.docs" = "https://docs.rs/%s/latest/";
      "searchurls.doc" = "https://docs.rs/%s1/latest/?search=%s2";
      "searchurls.nixos" = "https://search.nixos.org/options?channel=unstable&from=0&size=1000&sort=alpha_asc&query=%s";
      "searchurls.aur" = "https://aur.archlinux.org/packages/?K=%s";
      "searchurls.yt" = "https://www.youtube.com/results?search_query=%s";
      "searchurls.az" = "https://www.amazon.ca/s/ref=nb_sb_noss?url=search-alias%3Daps&field-keywords=%s";
      "searchurls.gw2" = "https://wiki.guildwars2.com/index.php?title=Special%3ASearch&search=%s&go=Go&ns0=1";
      "searchurls.gw2i" = "https://gw2efficiency.com/account/overview?filter.name=%s";
      "searchurls.gw2c" = "https://gw2efficiency.com/crafting/recipe-search?filter.orderBy=name&filter.search=%s";
      "searchurls.tf" = "https://registry.terraform.io/search/providers?q=%s";
      "searchurls.tfd" = "https://registry.terraform.io/providers/%s1/%s2/latest/docs";
      "searchurls.tfdh" = "https://registry.terraform.io/providers/hashicorp/%s/latest/docs";

      putfrom = "selection";
      # set yankto selection
      yankto = "both";
      externalclipboardcmd = xsel;
    };
    urlSettings = {
      allowautofocus = {
        "play\\.rust-lang\\.org" = { value = true; };
        "typescriptlang\\.org/play" = { value = true; };
        "danielyxie\\.github\\.io/bitburner/" = { value = true; };
      };
      editorcmd = {
        "github\\.com" = { value = "${urxvt} -e zsh -ic '${vim} %f \"+normal!%lG%c|\" \"+GHC\"'"; };
        "reddit\\.com" = { value = "${urxvt} -e zsh -ic '${vim} %f \"+normal!%lG%c|\" \"+M2A\"'"; };
      };
    };
  };
}
