{ config, pkgs, lib, ... } @ args: let
  # TODO: use lld? put a script called `ld.gold` in $PATH than just invokes ld.lld "$@" or patch gcc to accept -fuse-ld=lld
  rustGccGold = pkgs.writeScript "rust-gcc-gold" ''
    #!${pkgs.bash}/bin/sh
    exec ${pkgs.gcc} -fuse-ld=gold "$@"
  '';
  shellAliases = (if pkgs.targetPlatform.isDarwin then {
    ls = "ls -G";
  } else {
    cp = "cp --reflink=auto --sparse=auto";
    ls = "ls --color=auto";
  }) // {
    la = "ls -A";
    ll = "ls -lh";
    lla = "ll -A";

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

    # this really isn't correct but lorri doesn't have great semantics
    lorri-init = "echo 'eval \"$(lorri direnv)\"' > .envrc && lorri watch && direnv allow";

    ${if config.home.mutableHomeDirectory != null then "up" else null} = "${config.home.mutableHomeDirectory}/update";
    # TODO: darwin: brew update && brew upgrade?
  };
  shellInit = ''
    if [[ $TERM = rxvt-unicode* || $TERM = linux ]]; then
      TERM=linux ${pkgs.utillinux}/bin/setterm -regtabs 4
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
    zstyle ':completion:*' matcher-list 'r:|[._-]=** r:|=*' 'l:|=* r:|=*'
    zstyle ':completion:*:complete:pass:*:*' matcher 'r:|[./_-]=** r:|=*' 'l:|=* r:|=*'

    bindkey '^ ' autosuggest-accept

    ${lib.concatStringsSep "\n" (map (opt: "setopt ${opt}") zshOpts)}

    source ${files/zshrc-vimode}
    source ${files/zshrc-title}
    source ${files/zshrc-prompt}
  '';
in {
  options.home = {
    rust.enable = lib.mkEnableOption "rust development environment";
    profiles.base = lib.mkEnableOption "home profile: base";
    mutableHomeDirectory = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
    };
  };

  config = lib.mkIf config.home.profiles.base {
    home.stateVersion = "19.03";
    home.file = {
      # TODO: make a proper module for this
      ".local/share/bash/.keep".text = "";
      ".local/share/zsh/.keep".text = "";
      ".local/share/less/.keep".text = "";
      ".local/share/gnupg/.keep".text = ""; # TODO: directory needs restricted permissions
      ".local/share/vim/undo/.keep".text = "";
      ".local/share/vim/swap/.keep".text = "";
      ".local/share/vim/backup/.keep".text = "";
    };
    home.packages = with pkgs; [
      nix

      bash bash-completion
      zsh zsh-completions
      git
      gitAndTools.gitAnnex
      mosh
      tmux
      abduco
      openssh
      calc
      socat

      coreutils
      file

      nixos-option

      wget
      curl
      rsync
      sshfs
      gnupg

      p7zip
      unzip
      zip

      rxvt_unicode.terminfo

      lorri

      fzf fd # for fzf-z zsh plugin
    ] ++ (lib.optionals config.home.rust.enable [pkgs.cargo-download pkgs.cargo-expand pkgs.cargo-outdated]);
    xdg.enable = true;
    xdg.configFile = {
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
      "user-dirs.dirs".text = ''
        XDG_DESKTOP_DIR="$HOME"
        XDG_DOWNLOAD_DIR="$HOME/downloads"
      '';
      "inputrc".text = ''
        set editing-mode vi
        set keyseq-timeout 1
        set mark-symlinked-directories on

        set completion-prefix-display-length 3
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
      "cargo/config".text = if config.home.rust.enable then ''
        [target.x86_64-unknown-linux-gnu]
        linker = "${rustGccGold}"

        [target.x86_64-pc-windows-gnu]
        linker = "${pkgs.pkgsCross.mingwW64.buildPackages.gcc}/bin/x86_64-pc-mingw32-gcc"
        ar = "${pkgs.pkgsCross.mingwW64.buildPackages.binutils.bintools}/bin/x86_64-pc-mingw32-ar"

        [target.i686-pc-windows-gnu]
        linker = "${pkgs.pkgsCross.mingw32.buildPackages.gcc}/bin/i686-pc-mingw32-gcc"
        ar = "${pkgs.pkgsCross.mingw32.buildPackages.binutils.bintools}/bin/i686-pc-mingw32-ar"
      '' else "";
    };
    xdg.dataFile = {
      "z/.keep".text = "";
    };
    home.symlink = {
      ".gnupg".target = "${config.xdg.dataHome}/gnupg";
      ".local/share/gnupg/gpg-agent.conf".target = "${config.xdg.configHome}/gnupg/gpg-agent.conf";
      ".local/share/gnupg/gpg.conf".target = "${config.xdg.configHome}/gnupg/gpg.conf";
      ".local/share/gnupg/sshcontrol".target = "${config.xdg.configHome}/gnupg/sshcontrol";
      ".config/cargo/.crates.toml" = {
        target = "${config.xdg.dataHome}/cargo/.crates.toml";
        create = true;
      };
      ".config/cargo/bin" = {
        target = "${config.xdg.cacheHome}/cargo/bin/";
        create = true;
      };
      ".config/cargo/registry" = {
        target = "${config.xdg.cacheHome}/cargo/registry/";
        create = true;
      };
      ".config/cargo/git" = {
        target = "${config.xdg.cacheHome}/cargo/git/";
        create = true;
      };
    };
    home.sessionVariables = {
      INPUTRC = "${config.xdg.configHome}/inputrc";

      EDITOR = "${config.programs.vim.package}/bin/vim";

      PAGER = "${pkgs.less}/bin/less";
      LESS = "-KFRXMfnq";
      LESSHISTFILE = "${config.xdg.dataHome}/less/history";

      CARGO_HOME = "${config.xdg.configHome}/cargo";
    };
    home.shell = {
      aliases = shellAliases;
      functions = {
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
              ;;
            *)
              echo "unknown theme $1" >&2
              return 1
              ;;
          esac
        '';
      };
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

    programs.vim = {
      enable = true;
      plugins = [
        "vim-cool"
        "vim-ledger"
        "vim-dispatch"
        "vim-toml"
        "kotlin-vim"
        "swift-vim"
        "rust-vim"
        "notmuch-vim"
        "vim-colors-solarized"
        "vim-nix"
        "vim-osc52"
      ];
      settings = {};
      extraConfig = ''
        source ${./files/vimrc}
        source ${pkgs.substituteAll {
          src = ./files/vimrc-notmuch;
          inherit (pkgs) msmtp;
        }}
      '';
    };

    programs.git = {
      enable = true;
      aliases = {
        logs = "log --stat --pretty=medium --graph";
      };
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
        init = {
          templateDir = "${pkgs.gitAndTools.hook-chain}";
        };
        rebase = {
          autosquash = true;
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
      extraConfig = ''
        #PubkeyAcceptedKeyTypes=+ssh-dss # do I still need this?
        SendEnv=TERM_THEME
      '';
    };

    programs.tmux = {
      enable = true;
      aggressiveResize = true;
      baseIndex = 1;
      #escapeTime = 1;
      historyLimit = 50000;
      keyMode = "vi";
      resizeAmount = 4;
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
        set -g status-bg default
        set -g status-interval 0

        setw -g window-status-activity-style ""
        setw -g window-status-format "#[fg=blue,bg=brightblack,bold] #I #[fg=white,bg=black,nobold]#{?window_activity_flag,#[bg=brightcyan]#[bold],}#{?window_bell_flag,#[bg=red]#[bold],} #W "
        setw -g window-status-current-format "#[fg=black,bg=brightwhite,nobold] #I #[fg=black,bg=white,bold] #W "
        setw -g window-status-current-bg colour0
        setw -g window-status-current-fg colour11
        setw -g window-status-bg green
        setw -g window-status-fg black

        setw -g status-left "#[fg=black,bg=default,nobold][#[fg=blue]#S#[fg=black]]#[bg=default] "
        setw -g status-right "#[fg=black,bg=default,nobold][#[fg=blue]#h#[fg=black]]#[bg=default] "
      '';
    };

    dconf.enable = lib.mkDefault false; # TODO: is this just broken?
    services.sshd.authorizedKeys = [
      config.keychain.keys.satorin-ssh.path.public
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCik1rxKNKDBcIQrFrleGXlz/SwJXmC7TjAHqO3QXe0sIR4/egYhQlKSWLWiV/HviMJ0RNuBMNG6yfNpItNAvkKT9nExxyRFC4PAkYf4mBk6x4Re9hAE9FM9KAe7cFBx/+xD6VxJYGEoKyWejuCE16Tn48G7TEQyxr0bJwO9jL+LKAS+/Za3mx2kyKZNmn7b4Roa9uWeJDFpmzqsOmvxiLpF5sQ4EyKaiifyVUKaPGdoonVKXQMmnzyBP/e553raLYV13bGzPKBq8UnRHKmVbNSotIrGZ/X/PBT/Y8jRRZhba2hhai8ofGtkIhzdPWdTs30qlBrbRa2nEeVEVC6mKzv+gMtb0kiNOxb4ceKUpAntMUr2aCjsF1OTkROOqbLg8nTHAIM9JHFDNZmzDGa7kjtn4c8V4X/beydTAWNDClLG9CWwjG+X+ZpGsuOFX/ke62pcj44tK+qm1XckdX1HyCXrG7R4AeOyqZ8uXla5QoUgsK8qEa1ZFbRgQQtC595DvsQosfnJXrKuDurEeBfl/Ew4ugIHQvHioeAUAxG80WYJHyCfdh1V0a5fB19LEiWDZyy7uUqsuJYG8LWTrpJaM/PTbUaFI4No5vhSCKjmbFalJRhyGMbrhr+x7jnW1JRXS6lkvoDbJlUPLBRg63t6cZeXWCdMcXo1Me9Octc2XSSLQ== arc@shanghai"
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDMBsg/h3ITy/2u1IpTpazEMU+hKaThjC7wDPQzIKvicw6Hf+O7M8uw6DSFXAXhjygLvonhKhlVt6qKzrSJrKZDPewT/hkgFU2Zvj8JwWzSJKg9SYR6v0L1GYF2gB1K/QKNrXDxT0yoov/NDlN1lkVyYM9IMDRXVXx5SkojffMv9YC6NBZfOeaEmkKY3VCg5tePUF5limp9ipBzqjjIitDmNWBV/ID2paV/SIasGMfUFtipO5r8Bg4Wgv5sJPCWE82iYhZdJJkfHr8vn7M7ITMCQ00daSZlu2McCFkff+ZMe/wejX5xxyOXx9xI2yomzN77rMSl45pBp8MnHIigJ0zRiMSHfjpDkwVQiaMdMG6bti7wRbEw6fKWLHcRqnZ3sWMxNLNnSO8WGdAXt6WIPJ2IBSSp/XmDxFu30Ag9soOqprqTLVXzxfdj0vLAPdMRQI2LuVL4wNfXS7FJxiOs9oQFvxdaxmqxRyry3fafl2Z5epdgw3dgu2G7fkvy9NEuoFoZfYyNVFkIsJ/AktyFvr9ajimN1xfuyIlXXmZJRqoMQ8gZY+Qcguug2g9IhjRyVOglQiQp1V/JETtpScOFuD2xpwLTZ2Y3Ij21+XOnrI88Izcox+QAQvAyHGfoPwG5Zwj2A0gT+c9xaAEH+nQOyZ6xp5uY+7cpN/F0Z0XDRBWnvw== arc@shanghai-tan"
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCvdvIjXlLTpG2QlMi1kGYfgPXCDIsDM1Ldn4uPO3kz+uEJEgSrqVuKD71VAEZfN93HVZ4BoBTrjXC+jc0nSZjUgccCdo9aSZ87JbdocivNxwXxy9c/0B4+WU9+NB16VpVX+t43xgJxKfV9TW2QOLE0h0MMJizCsyX9rFMF4EOIR3TYe8Mm8x2L6axP4SZ7X+2aEyWg7VcEjzheKWvu+C4/B0c4D1/WtHcTrfy4/2urjvgYEXw5UVz7KOIXR0jIk2cvePOrjppDy8TjJxcm3zkFT4ZYuACWDiqfVZKuqAFI89kZ6fufbbHR1RilfHiehnPyzGj7KgPtwSgbxPJ9yvwX iphonese-prompt"
    ];
  };
}
