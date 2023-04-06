{ config, pkgs, lib, ... } @ args: with lib;
let
  shellInit = ''
    if [[ $TERM = rxvt-unicode* || $TERM = linux ]]; then
      TERM=linux ${pkgs.util-linux}/bin/setterm -regtabs 2
    fi
  '';
  shellLogin = ''
    ! ${config.systemd.package}/bin/systemctl --user -q is-system-running 2> /dev/null || ${config.systemd.package}/bin/systemctl --user import-environment TERMINFO_DIRS # gpg-agent/pinentry-curses needs this
  '';
  zshOpts = [
    "auto_pushd" "pushd_ignore_dups" "pushdminus"
    "rmstarsilent" "nonomatch" "long_list_jobs" "interactivecomments"
    "append_history" "hist_ignore_space" "hist_verify" "inc_append_history" "nosharehistory"
    "nomenu_complete" "auto_menu" "no_auto_remove_slash" "complete_in_word" "always_to_end" "nolistbeep" "autolist" "listrowsfirst"
  ];
  zshInit = ''
    zmodload -i zsh/complist
    zstyle ':completion:*' list-colors ""
    zstyle ':completion:*:*:*:*:*' menu select
    zstyle ':completion:*:cd:*' tag-order local-directories directory-stack path-directories
    zstyle ':completion:*:*:kill:*:processes' list-colors '=(#b) #([0-9]#) ([0-9a-z-]#)*=01;34=0=01'
    zstyle ':completion:*:*:*:*:processes' command "ps -u $USER -o pid,user,comm -w -w"
    zstyle ':completion:*' matcher-list 'r:|[._-]=* r:|=*' 'l:|=* r:|=*'
    #zstyle ':completion:*' matcher-list 'r:|=*' '+ r:|[._-]=** l:|=*'
    #zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z} r:|=*' '+ r:|[._-]=* l:|=*' # case-insensitive version of above
    #zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|=*' 'l:|=* r:|=*' # ?
    #fuzzy:
    #zstyle ':completion:*' matcher-list 'r:[[:ascii:]]||[[:ascii:]]=** r:|=* m:{a-z\-}={A-Z\_}'
    #zstyle ':completion:*' matcher-list 'r:|?=** m:{a-z\-}={A-Z\_}'
    zstyle ':completion:*:complete:pass:*:*' matcher 'r:|[./_-]=** r:|=*' 'l:|=* r:|=*'

    ${concatStringsSep "\n" (map (opt: "setopt ${opt}") zshOpts)}

    source ${./zshrc-vimode}
    if [[ $USER = $DEFAULT_USER && -z ''${SSH_CLIENT-} ]]; then
      ZSH_TAB_TITLE_DEFAULT_DISABLE_PREFIX=true
    fi
  '' + optionalString config.programs.zsh.enableAutosuggestions ''
    ZSH_AUTOSUGGEST_STRATEGY=(history completion)
    bindkey '^ ' autosuggest-accept
  '' + optionalString config.programs.fzf.enable ''
    bindkey "^_" fzf-history-widget # Ctrl+/
    bindkey "^P" fzf-file-widget
    bindkey "^Z" fzf-cd-widget
  '';
in {
  imports = [
    ../../modules/shell-deprecation-aliases.nix
    ./ls.nix
    ./nix.nix
    ./direnv-histfile.nix
  ];
  home.shell = {
    aliases = mkMerge [
      (mkIf pkgs.hostPlatform.isLinux {
        cp = "cp --reflink=auto --sparse=auto";
        sys = "systemctl";
        sysu = "systemctl --user";
        log = "journalctl";
        logu = "journalctl --user";
        dmesg = "dmesg -HP";
        open = "xdg-open";
      })
      {
        grep = "grep --color=auto";

        clear = "clear && printf '\\e[3J'";
        bell = "tput bel";
      }
    ];
    functions = {
      strings = mkIf pkgs.hostPlatform.isLinux ''
        nix shell nixpkgs#binutils -c strings "$@"
      '';
      dict = ''
        ${pkgs.curl}/bin/curl "dict://dict.org/$1:$2"
      '';
      # TODO: think this through more, theme configuration needs to be per session
      theme = ''
        case "$1" in
          isDark)
            [[ $(theme get) = dark ]]
            ;;
          get|"")
            echo ''${TERM_THEME-dark}
            ;;
          light|dark)
            export TERM_THEME=$1
            if [[ $TERM_THEME = dark ]]; then
              ${config.base16.shell.activate.dark}
            else
              ${config.base16.shell.activate.light}
            fi
            ;;
          *)
            echo "unknown theme $1" >&2
            return 1
            ;;
        esac
      '';
    };
    deprecationAliases = mkMerge [ {
      yes = "no";
    } (mkIf config.programs.page.enable {
      less = "page";
    }) (mkIf (!config.home.minimalSystem) {
      sed = "sd";
      find = "fd";
    }) ];
  };
  home.packages = let
    prargs = pkgs.writeShellScriptBin "prargs" ''
      printf '$# %i\n' "$#"

      if [[ $0 != *prargs ]]; then
        count=0
        args=("$0" "$@")
      else
        count=1
        args=("$@")
      fi

      for arg in "''${args[@]}"; do
        printf '%2s: "%b"\n' "$count" "$arg"
        count=$((count+1))
      done
    '';
  in [ prargs ];
  programs.bash = {
    enable = true;
    historyFile = "${config.xdg.dataHome}/bash/history";
    #historyIgnore = ["[bf]g" "exit" " *"]; # TODO: home-manager bug escape this properly
    historyControl = ["ignoredups"];
    localVariables = {
      HISTIGNORE = "[bf]g:exit: *";
      #TIMEFORMAT = ''"$'time\n%lS kernel, %lU userspace\n%lR elapsed (%P%% CPU)'"'';
      TIMEFORMAT = "time\n%lS kernel, %lU userspace\n%lR elapsed (%P%% CPU)";
      PS1 = ''"'\e[0;31m\u\e[1;39m@\e[0;31m\h \e[1;34m\w\n\e[1;37m:; \e[0m'"'';
    };
    profileExtra = ''
      ${shellLogin}
    '';
    initExtra = ''
      ${shellInit}

      bind -m vi-move 'W:shell-forward-word'
      bind -m vi-move 'B:shell-backward-word'

      source ${pkgs.bash-completion}/share/bash-completion/bash_completion
    '';
  };
  programs.zsh = {
    shellAliases = {
      history = "fc -il 1";
    };

    enable = true;
    enableAutosuggestions = true;
    enableCompletion = true;
    enableSyntaxHighlighting = true;
    autocd = true;
    defaultKeymap = "viins";
    dotDir = ".config/zsh";
    history = {
      path = "${config.xdg.dataHome}/zsh/history";
      size = 1000000;
      save = 1000000;
      extended = true;
      expireDuplicatesFirst = true;
    };
    dirHashes = mapAttrs (_: mkDefault) rec {
      dl = config.xdg.userDirs.download;
      music = config.xdg.userDirs.music;
      share = config.xdg.userDirs.publicShare;
      docs = config.xdg.userDirs.documents;
      pro = docs;
    };
    plugins = mkIf (!config.home.minimalSystem) [
      (with pkgs.zsh-z; {
        name = pname;
        inherit src;
      })
      pkgs.zsh-plugins.evil-registers.zshPlugin
      pkgs.zsh-plugins.tab-title.zshPlugin
    ];
    localVariables = {
      ZSH_HIGHLIGHT_HIGHLIGHTERS = [ "main" "brackets" ];
      READNULLCMD = config.home.sessionVariables.PAGER;
      REPORTTIME = 10;
      #TIMEFMT = ''"$'time %J\n%*S kernel, %*U userspace\n%*E elapsed (%P CPU)'"'';
      TIMEFMT = "time %J\n%*S kernel, %*U userspace\n%*E elapsed (%P CPU)";
      WORDCHARS = "-_~=&#$%^";
      PROMPT_EOL_MARK = "";
      KEYTIMEOUT = 1;
      DEFAULT_USER = "${config.home.username}";
      ZSH_TAB_TITLE_ENABLE_FULL_COMMAND= "true";
      ZSH_AUTOSUGGEST_USE_ASYNC = 1;
      ZSH_AUTOSUGGEST_MANUAL_REBIND = 1; # otherwise prompts get incredibly slow as $LINENO increases
      ZSHZ_DATA = "${config.xdg.dataHome}/z/data";
      ZSHZ_TILDE = 1;
      ZSHZ_UNCOMMON = 1;
      ZSHZ_CASE = "smart";
    };
    loginExtra = ''
      ${shellLogin}
    '';
    initExtra = ''
      ${shellInit}
      ${zshInit}
    '';
  };
  xdg.dataDirs = [
    "z"
    "bash"
    "zsh"
  ];
  programs.direnv = {
    enable = !config.home.minimalSystem;
    enableFishIntegration = false;
  };
}
