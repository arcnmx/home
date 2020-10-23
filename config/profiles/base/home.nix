{ config, pkgs, lib, ... } @ args: let
  inherit (config.lib.file) mkOutOfStoreSymlink;
  # TODO: use lld? put a script called `ld.gold` in $PATH than just invokes ld.lld "$@" or patch gcc to accept -fuse-ld=lld
  shellAliases = (if pkgs.hostPlatform.isDarwin then {
    ls = "ls -G";
  } else {
    cp = "cp --reflink=auto --sparse=auto";
    ls = "ls --color=auto";
  }) // {
    exa = "exa --time-style long-iso";
    ls = "exa -G";
    la = "exa -Ga";
    ll = "exa -l";
    lla = "exa -lga";

    sys = "systemctl";
    log = "journalctl";

    dmesg = "dmesg -HP";
    grep = "grep --color=auto";

    make = "make -j$(cpucount)";
    tnew = "tmux new -s";
    tatt = "tmux att -t";
    tmain = "tatt main";
    t3 = "tatt 3s";
    open = "xdg-open";
    clear = "clear && printf '\\e[3J'";

    ${if config.home.mutableHomeDirectory != null then "up" else null} = "${config.home.mutableHomeDirectory}/update";
  };
  shellInit = ''
    if [[ $TERM = rxvt-unicode* || $TERM = linux ]]; then
      TERM=linux ${pkgs.utillinux}/bin/setterm -regtabs 2
    fi
  '';
  shellLogin = ''
    ! ${pkgs.systemd}/bin/systemctl --user -q is-system-running 2> /dev/null || ${pkgs.systemd}/bin/systemctl --user import-environment TERMINFO_DIRS # gpg-agent/pinentry-curses needs this
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

    bindkey '^ ' autosuggest-accept

    ${lib.concatStringsSep "\n" (map (opt: "setopt ${opt}") zshOpts)}

    source ${files/zshrc-vimode}
    source ${files/zshrc-title}
    source ${files/zshrc-prompt}
  '';
in {
  options.home = {
    profiles.base = lib.mkEnableOption "home profile: base";
    mutableHomeDirectory = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
    };
  };

  config = lib.mkIf config.home.profiles.base {
    home.stateVersion = "19.03";
    home.file = {
      ".gnupg".source = mkOutOfStoreSymlink "${config.xdg.dataHome}/gnupg";
      ".gnupg/gpg.conf" = lib.mkIf config.programs.gpg.enable {
        target = "${config.xdg.configHome}/gnupg/gpg.conf";
      };
      ".gnupg/gpg-agent.conf" = lib.mkIf config.services.gpg-agent.enable {
        target = "${config.xdg.configHome}/gnupg/gpg-agent.conf";
      };
      ".markdownlintrc".source = mkOutOfStoreSymlink "${config.xdg.configHome}/markdownlint/markdownlintrc";
    } // lib.genAttrs [ "cargo/registry" "cargo/git" "cargo/bin" ] (path: {
      # ensure empty cache directories are created
      text = "";
      target = "${config.xdg.cacheHome}/${path}/.keep";
    });
    home.packages = with pkgs; [
      nix-readline

      bash # bash-completion
      zsh zsh-completions
      mosh-client
      tmux
      abduco
      openssh
      calc
      socat
      vimpager-latest

      coreutils
      file
      exa fd ripgrep hyperfine hexyl tokei

      wget
      curl
      rsync

      p7zip
      unzip
      zip

      rxvt-unicode-cvs-unwrapped.terminfo

      fzf fd # for fzf-z zsh plugin

      (if config.home.profiles.gui
        then clip.override { enableWayland = false; } # TODO: check config for wayland somehow?
        else clip.override { enableX11 = false; enableWayland = false; })
    ] ++ lib.optional (!config.home.profiles.personal) gitMinimal;
    home.nix.nixPath.ci = {
      type = "url";
      path = "https://github.com/arcnmx/ci/archive/master.tar.gz";
    };
    xdg.enable = true;
    xdg.configFile = {
      "vim/after/indent/rust.vim".text = ''
        setlocal comments=s0:/*!,m:\ ,ex:*/,s0:/*,mb:\ ,ex:*/,:///,://!,://
      '';
      "vim/after/indent/nix.vim".text = ''
        setlocal indentkeys=0{,0},0),0],:,0#,!^F,o,O,e,0=then,0=else,0=inherit,*<Return>
      '';
      "vim/after/indent/yaml.vim".text = ''
        setlocal indentkeys=!^F,o,O,0},0]
        set tabstop=2
        set softtabstop=2
        set shiftwidth=2
        set expandtab
      '';
      "vim/vimpagerrc".text = ''
        set noloadplugins

        if !exists('g:less')
          let g:less = {}
        endif
        if !exists('g:vimpager')
          let g:vimpager = {}
        endif

        " let g:less.enabled = 0
        let g:less.number = 1

        " alternate screen clears on exit :(
        " TODO: make t_te move up one line to accomodate the double-height prompt? also set cmdheight=2 so a line doesn't get clobbered when doing so
        set t_ti= t_te=

        " I want to select things in X thanks
        set mouse=
      '';
      "user-dirs.dirs".text = ''
        XDG_DESKTOP_DIR="$HOME"
        XDG_DOWNLOAD_DIR="$HOME/downloads"
      '';
      "inputrc".text = ''
        set editing-mode vi
        set keyseq-timeout 1
        set mark-symlinked-directories on

        set completion-prefix-display-length 8
        set show-all-if-ambiguous on
        set show-all-if-unmodified on
        set visible-stats on
        set colored-stats on

        set bell-style none

        set meta-flag on
        set input-meta on
        set convert-meta off
        set output-meta on
      '';
      "procps/toprc".source = ./files/toprc;
      "markdownlint/markdownlintrc".text = builtins.toJSON {
        "default" = true;
        "line-length" = false;
      };
      "cargo/config".text = ''
        [net]
        git-fetch-with-cli = true
      '';
      "cargo/.crates.toml".source = mkOutOfStoreSymlink "${config.xdg.dataHome}/cargo/.crates.toml";
      "cargo/bin".source = mkOutOfStoreSymlink "${config.xdg.cacheHome}/cargo/bin/";
      "cargo/registry".source = mkOutOfStoreSymlink "${config.xdg.cacheHome}/cargo/registry/";
      "cargo/git".source = mkOutOfStoreSymlink "${config.xdg.cacheHome}/cargo/git/";
    };
    xdg.dataFile = {
      "z/.keep".text = "";
      "bash/.keep".text = "";
      "zsh/.keep".text = "";
      "less/.keep".text = "";
      "gnupg/.keep".text = ""; # TODO: directory needs restricted permissions
      "vim/undo/.keep".text = "";
      "vim/swap/.keep".text = "";
      "vim/backup/.keep".text = "";
      "gnupg/gpg-agent.conf".source = mkOutOfStoreSymlink "${config.xdg.configHome}/gnupg/gpg-agent.conf";
      "gnupg/gpg.conf".source = mkOutOfStoreSymlink "${config.xdg.configHome}/gnupg/gpg.conf";
      "gnupg/sshcontrol".source = mkOutOfStoreSymlink "${config.xdg.configHome}/gnupg/sshcontrol";
    };
    home.language = {
      base = "en_US.UTF-8";
    };
    home.sessionVariables = {
      INPUTRC = "${config.xdg.configHome}/inputrc";

      EDITOR = "${config.programs.vim.package}/bin/vim";

      #PAGER = "${pkgs.less}/bin/less";
      PAGER = "${pkgs.vimpager-latest}/bin/vimpager";
      LESS = "-KFRXMfnq";
      LESSHISTFILE = "${config.xdg.dataHome}/less/history";

      #LC_COLLATE = "C";

      TERMINFO_DIRS = "\${TERMINFO_DIRS:-${config.home.homeDirectory}/.nix-profile/share/terminfo:/usr/share/terminfo}";

      CARGO_HOME = "${config.xdg.configHome}/cargo";
      CARGO_TARGET_DIR = "${config.xdg.cacheHome}/cargo/target";
      TIME_STYLE = "long-iso";

      # workaround home-manager bug improperly escaping this
      TMUX_TMPDIR = lib.mkIf (config.programs.tmux.enable && config.programs.tmux.secureSocket) (lib.mkForce
        ''''${XDG_RUNTIME_DIR:-"/run/user/$(id -u)"}''
      );
    };
    base16 = (if config.home.nixosConfig != null then {
      inherit (config.home.nixosConfig.base16) schemes alias;
    } else import ./base16.nix { inherit config; }) // {
      shell.enable = true;
    };
    home.shell = {
      aliases = shellAliases;
      functions = {
        # helper for use with `nix -I $(nixpkgs unstable)`
        nixpkgs = ''
          echo "nixpkgs=https://nixos.org/channels/$1/nixexprs.tar.xz"
        '';
        cpucount = if pkgs.hostPlatform.isDarwin then ''
          sysctl -n hw.logicalcpu_max
        '' else ''
          ${pkgs.coreutils}/bin/nproc 2> /dev/null || ${pkgs.coreutils}/bin/grep -c '^processor' /proc/cpuinfo
        '';
        prargs = ''
          printf '"%b"\n' "$0" "$@" | ${pkgs.coreutils}/bin/nl -v0 -s": "
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
                source ${config.lib.arc.base16.shellScriptForAlias.dark}
              else
                source ${config.lib.arc.base16.shellScriptForAlias.light}
              fi
              ;;
            *)
              echo "unknown theme $1" >&2
              return 1
              ;;
          esac
        '';
      };
    };
    programs.less = {
      enable = true;
      lesskey.extraConfig = ''
        #command
        h left-scroll
        l right-scroll
      '';
    };
    programs.bash = {
      enable = true;
      historyFile = "${config.xdg.dataHome}/bash/history";
      #historyIgnore = ["[bf]g" "exit" " *"]; # TODO: home-manager bug escape this properly
      historyControl = ["ignoredups"];
      localVariables = {
        HISTIGNORE = "[bf]g:exit: *";
        #TIMEFORMAT = ''"$'time\n%lS kernel, %lU userspace\n%lR elapsed (%P%% CPU)'"'';
        TIMEFORMAT = "time\n%lS kernel, %lU userspace\n%lR elapsed (%P%% CPU)";
        PS1 = ''"'\[\e[0;31m\]\u\[\e[1;39m\]@\[\e[0;31m\]\h \[\e[1;34m\]\w\n\[\e[1;37m\]:; \[\e[0m\]'"'';
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
      defaultKeymap = "viins";
      dotDir = ".config/zsh";
      history = {
        path = ".local/share/zsh/history";
        size = 100000;
        save = 100000;
        extended = true;
        ignoreDups = true;
        expireDuplicatesFirst = true;
      };
      plugins = [
        {
          name = "z";
          file = "z.sh";
          src = pkgs.fetchFromGitHub {
            owner = "rupa";
            repo = "z";
            rev = "9d5a3fe0407101e2443499e4b95bca33f7a9a9ca";
            sha256 = "0aghw6zmd3851xpzgy0jkh25wzs9a255gxlbdr3zw81948qd9wb1";
          };
        }
        {
          name = "fzf-z";
          src = pkgs.fetchFromGitHub {
            owner = "andrewferrier";
            repo = "fzf-z";
            rev = "089ba6cacd3876c349cfb6b65dc2c3e68b478fd0";
            sha256 = "1lvvkz0v4xibq6z3y8lgfkl9ibcx0spr4qzni0n925ar38s20q81";
          };
        }
        {
          name = "zsh-abduco-completion";
          src = pkgs.fetchFromGitHub {
            owner = "arcnmx";
            repo = "zsh-abduco-completion";
            rev = "d8df9f1343d33504d43836d02f0022c1b2b21c0b";
            sha256 = "1n40c2dk7hcpf0vjj6yk0d8lvppsk2jb02wb0zwlq5r72p2pydxf";
          };
        }
        (with pkgs.zsh-syntax-highlighting; {
          name = "zsh-syntax-highlighting";
          inherit src;
        })
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
        ZSH_AUTOSUGGEST_USE_ASYNC = 1;
        _Z_DATA = "${config.xdg.dataHome}/z/data";
        #_Z_OWNER = "arc";
      };
      loginExtra = ''
        ${shellLogin}
      '';
      initExtra = ''
        ${shellInit}
        ${zshInit}
      '';
    };

    programs.kakoune = {
      enable = true;
      config = {
        tabStop = 2;
        indentWidth = 0; # default = 4, 0 = tabs
        scrollOff = {
          lines = 4;
          columns = 4;
        };
        ui = {
          setTitle = false; # or true? depends if you can control format, I just want the filename
          statusLine = "bottom";
          assistant = "cat";
          enableMouse = true; # hmmmm
          changeColors = true; # what is this?
          wheelDownButton = null;
          wheelUpButton = null;
          #shiftFunctionKeys = 12; # um is this useful?
          useBuiltinKeyParser = false; # what's this for?
        };
        showMatching = true;
        wrapLines = {
          enable = true;
          word = true;
          indent = true; # this is probably too weird
          marker = "↪"; # ↳
        };
        numberLines = {
          enable = true;
          relative = true;
          highlightCursor = true;
          #separator = "";
        };
        showWhitespace = {
          enable = true;
          nonBreakingSpace = "·";
          tab = "»";
        };
        keyMappings = [
          {
            mode = "insert";
            docstring = "completion nav down";
            key = "<a-j>";
            effect = "<c-n>";
          }
          {
            mode = "insert";
            docstring = "completion nav up";
            key = "<a-k>";
            effect = "<c-p>";
          }
        ];
        hooks = [
          /*{
            name = "NormalBegin";
            once = false;
            group = "group";
            option = "filetype=rust";
            commands = ''
            '';
          }*/
        ];
      };
      pluginsExt = with pkgs.kakPlugins; [
        kak-crosshairs
        kakoune-registers
        explore-kak
        fzf-kak
      ];
      extraConfig = ''
        colorscheme tomorrow-night
      '';
      # TODO: make a base16 colorscheme compatible with base16-shell?
      # see https://github.com/Delapouite/base16-kakoune/blob/master/build.js
    };
    programs.vim = {
      enable = true;
      packageConfigurable = pkgs.vim_configurable-pynvim;
      plugins = [
        "vim-cool"
        "vim-ledger"
        "vim-dispatch"
        "vim-toml"
        "kotlin-vim"
        "swift-vim"
        "rust-vim"
        "vim-nix"
        "vim-osc52"
        "base16-vim"
      ];
      settings = {};
      extraConfig = ''
        source ${./files/vimrc}

        " alt-hjkl for moving around word-wrapped lines
        nnoremap <M-h> gh
        nnoremap <M-j> gj
        nnoremap <M-k> gk
        nnoremap <M-l> gl

        " trying alternatives to Esc for exiting insert mode
        inoremap kj <Esc>`^
        inoremap lkj <Esc>`^:w<CR>
        inoremap ;lkj <Esc>:wq<CR>

        cmap <M-h> <Left>
        cmap <M-j> <Down>
        cmap <M-k> <Up>
        cmap <M-l> <Right>
        cmap <M-0> <Home>

        imap <C-l> <C-O>:redr!<CR>

        set cmdheight=2 updatetime=300 shortmess+=c
      '';
    };

    programs.rustfmt = {
      enable = true;
      package = lib.mkDefault null;
      config = {
        edition = "2018";
        unstable_features = true;
        skip_children = true;
        wrap_comments = true;
        hard_tabs = true;
        tab_spaces = 4;
        max_width = 120;
        comment_width = 100;
        condense_wildcard_suffixes = true;
        format_code_in_doc_comments = true;
        #format_strings = true;
        match_arm_blocks = false;
        #match_block_trailing_comma = true;
        overflow_delimited_expr = true;
        merge_imports = true;
        reorder_impl_items = true;
        newline_style = "Unix";
        normalize_comments = true;
        #normalize_doc_attributes = true; # except when have I ever explicitly used #[doc = ...]?
        #report_fixme, report_todo
        #struct_lit_single_line = false;
        trailing_semicolon = false;
        use_field_init_shorthand = true;
        use_try_shorthand = true;
        #where_single_line = true;
      };
    };

    programs.git = {
      enable = true;
      package = if config.home.profiles.personal then pkgs.git else pkgs.gitMinimal;
      aliases = {
        logs = "log --stat --pretty=medium --graph";
        reattr = ''!sh -c "\"git stash push -q; rm .git/index; git checkout HEAD -- \\\"$(git rev-parse --show-toplevel)\\\"; git stash pop || true\""'';
        fixup = ''!sh -c "\"git commit --fixup HEAD && git rebase -i HEAD~2\""'';
      };
      ignores = [
        ".envrc"
      ];
      extraConfig = {
        user = {
          useConfigOnly = true;
        };
        color = {
          ui = "auto";
        };
        push = {
          default = "simple";
        };
        #init = {
        #  templateDir = "${pkgs.gitAndTools.hook-chain}";
        #};
        annex = {
          autocommit = false;
          backend = "SHA256"; # TODO: blake3 when?
          synccontent = true;
        };
        rebase = {
          autoSquash = true;
          autoStash = true;
        };
        merge = {
          conflictstyle = "diff3";
        };
        filter.tabspace = {
          smudge = "${pkgs.coreutils}/bin/unexpand --first-only --tabs=4";
          clean = "${pkgs.coreutils}/bin/expand -i --tabs=4";
        };
      };
    };

    programs.direnv = {
      enable = true;
      enableFishIntegration = false;
      #config = { };
      #stdlib = "";
    };

    programs.ssh = {
      enable = true;
      compression = true;
      controlMaster = "auto";
      #controlPath = "/run/user/%i/%C-%n"; # mine but sometimes gets too long
      #controlPath = "~/.ssh/master-%r@%n:%p"; # default
      controlPersist = "1m";
      serverAliveInterval = 60;
      #PubkeyAcceptedKeyTypes=+ssh-dss # do I still need this?
      extraConfig = ''
        SendEnv=TERM_THEME
      '';
      knownHosts = [
        "satorin ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFgcPU64V9VTwqGZ5GtaqXZd1o/T+58/VXsSfp+nUl6Q"
        "shanghai ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEx8KadgtdeLNmQrEGRqoVE/c5zMMBQ3O7SgAsfTOfZK"
      ];
    };

    programs.tmux = {
      enable = true;
      aggressiveResize = true;
      baseIndex = 1;
      escapeTime = 1;
      historyLimit = 50000;
      keyMode = "vi";
      resizeAmount = 4;
      customPaneNavigationAndResize = true;
      shortcut = "a";
      terminal = "screen-256color";
      tmuxp.enable = true;
      extraConfig = ''
        set -g mouse off

        bind C-m \
          set -g mouse on \;\
          display 'Mouse: ON'

        bind m \
          set -g mouse off \;\
          display 'Mouse: OFF'

        # y and p
        bind Escape copy-mode
        unbind p
        bind p paste-buffer
        bind -T copy-mode-vi 'v' send -X begin-selection
        bind -T copy-mode-vi 'y' send -X copy-selection
        bind -T copy-mode-vi 'Space' send -X halfpage-down
        bind -T copy-mode-vi 'Bspace' send -X halfpage-up

        # extra commands for interacting with the ICCCM clipboard
        bind C-c run "tmux save-buffer - | xclip -i -sel clipboard"
        bind C-v run "tmux set-buffer \"$(xclip -o -sel clipboard)\"; tmux paste-buffer"

        bind -T copy-mode-vi 'C-y' send -X copy-pipe "xclip -i"
        bind y run "tmux save-buffer - | xclip -i"
        bind C-p run "tmux set-buffer \"$(xclip -o)\"; tmux paste-buffer"

        # selection with <prefix>v
        bind v copy-mode
        unbind [

        # easy-to-remember split pane commands
        bind | split-window -h
        bind - split-window -v
        unbind '"'
        unbind %

        # moving between windows with vim movement keys
        bind -r h select-pane -L
        bind -r l select-pane -R
        bind -r k select-pane -U
        bind -r j select-pane -D
        bind -r C-h select-window -t :-
        bind -r C-l select-window -t :+

        # kill
        bind X confirm-before -p "kill-window #W? (y/n)" kill-window

        # bell
        setw -g monitor-activity on
        setw -g monitor-bell on
        set -g visual-activity off
        set -g visual-bell off
        set -g bell-action any
        set -g activity-action none

        # status line
        set -g status-justify left
        set -g status-style bg=default
        set -g status-interval 0

        setw -g window-status-activity-style ""
        setw -g window-status-format "#[fg=blue,bg=brightblack,bold] #I #[fg=white,bg=black,nobold]#{?window_activity_flag,#[bg=brightcyan]#[bold],}#{?window_bell_flag,#[bg=red]#[bold],} #W "
        setw -g window-status-current-format "#[fg=black,bg=brightwhite,nobold] #I #[fg=black,bg=white,bold] #W "
        setw -g window-status-current-style fg=colour11,bg=colour0
        setw -g window-status-style bg=green,fg=black

        setw -g status-left "#[fg=black,bg=default,nobold][#[fg=blue]#S#[fg=black]]#[bg=default] "
        setw -g status-right "#[fg=black,bg=default,nobold][#[fg=blue]#h#[fg=black]]#[bg=default] "
      '';
    };

    dconf.enable = lib.mkDefault false; # TODO: is this just broken?
  };
}
