{ base16, options, config, pkgs, lib, ... } @ args: with lib;
let
  inherit (config.lib.file) mkOutOfStoreSymlink;
  vimPlugins = with pkgs.vimPlugins; [
    vim-cool
    vim-ledger
    vim-dispatch
    vim-lastplace
    vim-commentary
    vim-surround
    vim-toml
    kotlin-vim
    swift-vim
    rust-vim
    vim-nix
    vim-osc52
  ];
  shellAliases = (if pkgs.hostPlatform.isDarwin then {
    ls = "ls -G";
  } else {
    cp = "cp --reflink=auto --sparse=auto";
    ls = "ls --color=auto";
  }) // {
    sys = "systemctl";
    log = "journalctl";

    dmesg = "dmesg -HP";
    grep = "grep --color=auto";

    make = "make -j$(cpucount)";
    open = "xdg-open";
    clear = "clear && printf '\\e[3J'";
    bell = "tput bel";

    ${if config.home.mutableHomeDirectory != null then "up" else null} = "${config.home.mutableHomeDirectory}/update";
  } // optionalAttrs (!config.home.minimalSystem) {
    exa = "exa --time-style long-iso";
    ls = "exa -G";
    la = "exa -Ga";
    ll = "exa -l";
    lla = "exa -lga";
  } // optionalAttrs config.home.minimalSystem {
    la = "ls -A";
    ll = "ls -lh";
    lla = "ls -lhA";
    grep = "grep --color=auto";
  } // optionalAttrs config.programs.tmux.enable {
    tnew = "tmux new -s";
    tatt = "tmux att -t";
    tmain = "tatt main";
  };
  shellFunAlias = command: replacement: ''
    if [[ ! -t 0 ]]; then
      command ${command} $@
    else
      echo 'use ${replacement}!'
    fi
  '';
  shellFunAliases = mapAttrs shellFunAlias;
  shellInit = ''
    if [[ $TERM = rxvt-unicode* || $TERM = linux ]]; then
      TERM=linux ${pkgs.utillinux}/bin/setterm -regtabs 2
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

    bindkey '^ ' autosuggest-accept

    ${lib.concatStringsSep "\n" (map (opt: "setopt ${opt}") zshOpts)}

    source ${files/zshrc-vimode}
    if [[ $USER = $DEFAULT_USER && -z ''${SSH_CLIENT-} ]]; then
      ZSH_TAB_TITLE_DEFAULT_DISABLE_PREFIX=true
    fi
  '';
in {
  imports = [
    ./base16.nix
  ];

  options.home = {
    profiles.base = lib.mkEnableOption "home profile: base";
    minimalSystem = mkOption {
      type = types.bool;
      default = false;
    };
    mutableHomeDirectory = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
    };
  };

  config = lib.mkIf config.home.profiles.base {
    home.stateVersion = "21.05";
    home.file = {
      ".gnupg".source = mkOutOfStoreSymlink "${config.xdg.dataHome}/gnupg";
      ".gnupg/gpg.conf" = lib.mkIf config.programs.gpg.enable {
        target = "${config.xdg.configHome}/gnupg/gpg.conf";
      };
      "${config.programs.gpg.homedir}/gpg-agent.conf" = lib.mkIf config.services.gpg-agent.enable {
        target = "${config.xdg.configHome}/gnupg/gpg-agent.conf";
      };
      ".markdownlintrc".source = mkOutOfStoreSymlink "${config.xdg.configHome}/markdownlint/markdownlintrc";
    } // lib.genAttrs [ "cargo/registry" "cargo/git" "cargo/bin" ] (path: {
      # ensure empty cache directories are created
      text = "";
      target = "${config.xdg.cacheHome}/${path}/.keep";
    });
    home.packages = with pkgs; mkMerge [ [
      abduco
      socat

      curl
      rsync

      buildPackages.rxvt-unicode-cvs-unwrapped.terminfo
    ] (mkIf (!config.home.minimalSystem) [
      file

      p7zip
      unzip
      zip

      mosh-client
      calc
      exa fd ripgrep hyperfine hexyl tokei
    ]) (mkIf (!config.home.minimalSystem && ! config.home.nixosConfig ? nix.package) [
      nix-readline
    ]) (mkIf config.programs.git.enable [
      gitAndTools.git-fixup
    ]) (mkIf (!config.home.profiles.gui) [
      (clip.override { enableX11 = false; enableWayland = false; })
    ]) ];
    home.nix.nixPath.ci = {
      type = "url";
      path = "https://github.com/arcnmx/ci/archive/master.tar.gz";
    };
    home.keyboard = mkDefault null;
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
      "vim/vimpagerrc" = mkIf config.programs.vim.enable {
        text = ''
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
      };
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
    xdg.userDirs = {
      enable = true;
      createDirectories = true;
      desktop = "$HOME";
      download = "$HOME/downloads";
      music = "$HOME/media/music";
      pictures = "$HOME/media/pictures";
      videos = "$HOME/media/videos";
      publicShare = "$HOME/share/public";
      templates = "$HOME/templates";
      documents = "$HOME/projects";
    };
    xdg.mimeApps = {
      enable = true;
    };
    home.language = {
      base = "en_US.UTF-8";
    };
    home.sessionVariables = mkMerge [ {
      INPUTRC = "${config.xdg.configHome}/inputrc";

      LESS = "-KFRXMfnq";
      LESSHISTFILE = "${config.xdg.dataHome}/less/history";

      #LC_COLLATE = "C";

      TERMINFO_DIRS = "\${TERMINFO_DIRS:-${config.home.profileDirectory}/share/terminfo:/usr/share/terminfo}";

      CARGO_HOME = "${config.xdg.configHome}/cargo";
      CARGO_TARGET_DIR = "${config.xdg.cacheHome}/cargo/target";
      TIME_STYLE = "long-iso";
    } (mkIf config.programs.neovim.enable {
      EDITOR = "nvim";
    }) (mkIf (!config.programs.page.enable && config.programs.vim.enable) {
      PAGER = "${pkgs.vimpager-latest}/bin/vimpager";
    }) (mkIf (!config.programs.page.enable && !config.programs.vim.enable) {
      PAGER = "${pkgs.less}/bin/less";
    }) (mkIf (config.programs.vim.enable && !config.programs.neovim.enable) {
      EDITOR = "${config.programs.vim.package}/bin/vim";
    }) ];
    base16 = {
      shell.enable = true;
      vim.template = data: let
        drv = pkgs.base16-templates.vim.withTemplateData data;
      in drv.overrideAttrs (old: {
        src = pkgs.fetchFromGitHub {
          repo = "base16-vim";
          owner = "fnune";
          rev = "52e4ce93a6234d112bc88e1ad25458904ffafe61";
          sha256 = "10y8z0ycmdjk47dpxf6r2pc85k0y19a29aww99vgnxp31wrkc17h";
        };
        patches = old.patches or [ ] ++ [
          (pkgs.fetchurl {
            # base16background=none
            url = "https://github.com/arcnmx/base16-vim/commit/fe16eaaa1de83b649e6867c61494276c1f35c3c3.patch";
            sha256 = "1c0n7mf6161mvxn5xlabhyxzha0m1c41csa6i43ng8zybbspipld";
          })
          (pkgs.fetchurl {
            # fix unreadable error highlights under cursor
            url = "https://github.com/arcnmx/base16-vim/commit/807e442d95c57740dd3610c9f9c07c9aae8e0995.patch";
            sha256 = "1l3qmk15v8d389363adkmfg8cpxppyhlk215yq3rdcasvw7r8bla";
          })
        ];
      });
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
      } // shellFunAliases ({
        yes = "no";
      } // optionalAttrs config.home.profiles.personal {
        ncpamixer = "pulsemixer";
      } // optionalAttrs config.home.profiles.gui {
        feh = "imv";
      } // optionalAttrs (!config.home.minimalSystem) {
        sed = "sd";
        find = "fd";
        grep = "rg";
      });
    };
    programs.less = {
      enable = true;
      keys = ''
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
      plugins = lib.mkIf (!config.home.minimalSystem) [
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
    programs.starship = with base16.map.ansiStr; let
      bg = "bg:${background_status}";
      substitutions = let
        expand = replaceStrings [ "$HOME" ] [ "~" ];
        mapDir = name: dir: nameValuePair (expand dir) "~${name}";
      in mapAttrs' mapDir config.programs.zsh.dirHashes;
      substitutionsList = mapAttrsToList (name: value: { inherit name value; }) substitutions;
      orderedSubstitutions = sort (a: b: a.name > b.name) substitutionsList;
    in {
      enable = mkDefault (!config.home.minimalSystem);
      extraConfig = mkMerge (
        singleton "[directory.substitutions]"
        ++ map ({ name, value }: ''"${name}" = "${value}"'') orderedSubstitutions
      );
      settings = {
        command_timeout = 200;
        add_newline = false;
        format =
          "[$username$hostname$directory$all$shlvl$jobs$status$cmd_duration$fill$line_break](${bg} fg:${foreground_status})"
          + "$shell$character";
        right_format = "$package$battery$time";
        character = {
          format = "$symbol; ";
          success_symbol = ":";
          error_symbol = "[!](bold fg:${deleted})";
          vicmd_symbol = " ";
        };
        time = {
          format = "[🕓$time]($style)";
          style = "bold fg:${deprecated}";
          disabled = false;
        };
        fill = {
          symbol = " ";
          style = bg;
        };
        cmd_duration = {
          format = "[~$duration]($style)";
          style = "${bg} fg:${comment}";
          show_notifications = true;
        };
        directory = {
          truncation_length = 0;
          truncate_to_repo = false;
          truncation_symbol = "…/";
          style = "${bg} bold fg:${function}";
        };
        env_var = { }; # TODO
        git_branch = {
          format = "[$symbol$branch]($style) ";
          style = "${bg} fg:${class}";
          symbol = "";
          #only_attached = true;
        };
        git_commit = {
          tag_disabled = false;
          inherit (config.programs.starship.settings.git_branch) style;
        };
        git_state = {
          # in-progress rebase/etc indicator
          format = "[:: $state( $progress_current/$progress_total)]($style) ";
          style = "${bg} bold fg:${deleted}";
        };
        git_status = {
          style = "${bg} fg:${deprecated}";
          # omit information that causes the prompt to lag severely: https://github.com/starship/starship/pull/3287
          ahead = "";
          behind = "";
          up_to_date = "";
          diverged = "";
          ignore_submodules = true;
          untracked = ""; # I kind of would like to keep this though..?
        };
        username = {
          format = "[$user]($style)@";
          style_user = "${bg} fg:${constant}";
          style_root = "${bg} bold fg:${keyword}";
        };
        hostname = {
          format = "[$hostname]($style):";
          style = "${bg} fg:${class}";
        };
        jobs = {
          style = "${bg} fg:${comment}";
        };
        nix_shell = {
          format = '' [$symbol($name)]($style) '';
          style = "${bg} fg:${support}";
          symbol = "#";
        };
        shlvl = {
          disabled = false;
          style = "${bg} bold fg:${deprecated}";
          symbol = "›";
          repeat = true;
          threshold = 3;
        };
        status = {
          disabled = false;
          format = "[$symbol$status]($style) ";
          symbol = "";
          success_symbol = "";
          sigint_symbol = "^";
          map_symbol = true;
          pipestatus = true;
          style = "${bg} bold fg:${deleted}";
        };
        package = {
          format = "[$symbol$version]($style) ";
          style = "bold fg:${class}";
        };
      } // mapListToAttrs (k: nameValuePair k { disabled = mkOptionDefault true; }) [
        # disable most builtin modules I'd never use...
        "aws" "battery" "docker_context" "gcloud" "kubernetes" "openstack" "pulumi" "singularity" "terraform" "vagrant" "vcsh"
        # useless modules that just show version numbers...
        "golang" "helm" "java" "julia" "cmake" "cobol" "conda" "crystal" "dart" "deno" "dotnet" "elixir" "elm" "erlang" "kotlin" "lua" "nim" "nodejs" "ocaml" "perl" "php" "purescript" "python" "rlang" "red" "ruby" "rust" "scala" "swift" "vlang" "zig"
        # sorry mercurial
        "hg_branch"
      ];
    };
    programs.fzf = {
      enable = !config.home.minimalSystem;
      enableZshIntegration = true;
    };
    programs.man.enable = !config.home.minimalSystem;

    programs.kakoune = {
      enable = !config.home.minimalSystem;
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
      enable = mkDefault (!config.programs.neovim.enable);
      plugins = vimPlugins;
      settings = {};
      extraConfig = mkMerge [ (mkBefore ''
        let base16background='none' " activate patch to disable solid backgrounds
      '') ''
        source ${./files/vimrc-vim}
        source ${./files/vimrc}
        source ${./files/vimrc-keys}
      '' ];
      packageConfigurable = if config.home.minimalSystem
        then pkgs.vim_configurable.override {
          guiSupport = "no";
          luaSupport = false;
          multibyteSupport = true;
          ftNixSupport = false;
        } else pkgs.vim_configurable-pynvim;
    };
    programs.neovim = {
      vimAlias = !config.programs.vim.enable;
      vimdiffAlias = true;
      plugins = vimPlugins;
      extraConfig = mkMerge [ (mkBefore ''
        let base16background='none' " activate patch to disable solid backgrounds
      '') ''
        source ${./files/vimrc}
        source ${./files/vimrc-keys}
        source ${./files/vimrc-nvim.lua}
        source ${./files/vimrc-page.lua}
      '' ];
    };
    programs.page = {
      enable = !config.home.minimalSystem && config.programs.neovim.enable;
      package = pkgs.page-develop;
      manPager = true;
      queryLines = 80000; # because of how nvim terminal treats long lines (it breaks lines instead of wrapping them), this can go over
      openLines = {
        enable = true;
        promptHeight = 2;
      };
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
        tab_spaces = 2;
        max_width = 120;
        comment_width = 100;
        condense_wildcard_suffixes = true;
        format_code_in_doc_comments = true;
        #format_strings = true;
        match_arm_blocks = false;
        #match_block_trailing_comma = true;
        overflow_delimited_expr = true;
        merge_imports = true;
        imports_granularity = "One";
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
      enable = !config.home.minimalSystem;
      package = if config.home.profiles.personal then pkgs.git else pkgs.gitMinimal;
      aliases = {
        logs = "log --stat --pretty=medium --graph";
        reattr = "!${pkgs.writeShellScript "git-reattr.sh" ''
          git stash push -q
          rm .git/index
          git checkout HEAD -- "$(git rev-parse --show-toplevel)"
          git stash pop || true
        ''}";
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
      enable = !config.home.minimalSystem;
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
