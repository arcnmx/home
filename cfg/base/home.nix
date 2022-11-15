{ nixosConfig, config, pkgs, lib, ... } @ args: with lib;
let
  inherit (config.lib.file) mkOutOfStoreSymlink;
in {
  imports = [
    ../../modules/keep-dirs.nix
    ../../modules/open.nix
    ./base16.nix
    ./bitw.nix
    ./email.nix
    ../weechat/autosort.nix
    ../starship
    ../shell
    ../ssh/home.nix
    ../tmux
    ../git
    ../vim
    ../kak
  ];

  options.home = {
    minimalSystem = mkOption {
      type = types.bool;
      default = nixosConfig.home.minimalSystem;
    };
    profileSettings.base.clip = mkOption {
      type = types.package;
      default = pkgs.clip.override { enableX11 = false; enableWayland = false; };
    };
  };

  config = {
    home.stateVersion = mkDefault "22.11";
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

      buildPackages.rxvt-unicode-unwrapped.terminfo
    ] (mkIf (!config.home.minimalSystem) [
      file

      p7zip
      unzip
      zip

      mosh-client
      calc
      fd ripgrep hyperfine hexyl tokei
      config.home.profileSettings.base.clip
    ]) (mkIf (!config.home.minimalSystem && ! config.home.nixosConfig ? nix.package) [
      nix-readline
    ]) ];
    home.nix.nixPath.ci = {
      type = "url";
      path = "https://github.com/arcnmx/ci/archive/master.tar.gz";
    };
    xdg.enable = true;
    xdg.configFile = {
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
    xdg.dataDirs = [
      "less"
      "gnupg" # TODO: directory needs restricted permissions
    ];
    xdg.dataFile = {
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
    home.sessionVariables = {
      INPUTRC = "${config.xdg.configHome}/inputrc";

      LESS = "-KFRXMfnq";
      LESSHISTFILE = "${config.xdg.dataHome}/less/history";

      #LC_COLLATE = "C";

      TERMINFO_DIRS = "\${TERMINFO_DIRS:-${config.home.profileDirectory}/share/terminfo:/usr/share/terminfo}";

      CARGO_HOME = "${config.xdg.configHome}/cargo";
      CARGO_TARGET_DIR = "${config.xdg.cacheHome}/cargo/target";
      TIME_STYLE = "long-iso";
    };
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
    programs.less = {
      enable = true;
      keys = ''
        #command
        h left-scroll
        l right-scroll
      '';
    };
    programs.fzf = {
      enable = !config.home.minimalSystem;
      enableZshIntegration = true;
      defaultCommand = "${pkgs.fd}/bin/fd --type f --type l";
      defaultOptions = [
        "--height 40%"
        "--border"
      ];
      historyWidgetOptions = [
        "--sort"
        "--exact"
      ];
      fileWidgetCommand = "${pkgs.fd}/bin/fd --type f";
      fileWidgetOptions = [
        "--prefix 'head {}'"
      ];
      changeDirWidgetCommand = "${pkgs.fd}/bin/fd --type d";
      changeDirWidgetOptions = [
        "--preview 'tree -C {} | head -n256'"
      ];
    };
    programs.man.enable = !config.home.minimalSystem;

    programs.rustfmt = {
      enable = true;
      package = lib.mkDefault null;
      config = rec {
        edition = "2021";
        unstable_features = true;
        wrap_comments = true;
        hard_tabs = true;
        tab_spaces = 2;
        max_width = 120;
        comment_width = 100;
        condense_wildcard_suffixes = true;
        format_code_in_doc_comments = !hard_tabs; # would be good if it didn't also use hard tabs...
        #format_strings = true;
        match_arm_blocks = false;
        #match_block_trailing_comma = true;
        overflow_delimited_expr = true;
        imports_granularity = "One";
        group_imports = "One";
        reorder_impl_items = true;
        force_multiline_blocks = false;
        newline_style = "Unix";
        normalize_comments = false;
        #normalize_doc_attributes = true; # except when have I ever explicitly used #[doc = ...]?
        #report_fixme, report_todo
        #struct_lit_single_line = false;
        trailing_semicolon = false;
        use_field_init_shorthand = true;
        use_try_shorthand = true;
        #where_single_line = true;
      };
    };

    programs.direnv = {
      enable = !config.home.minimalSystem;
      enableFishIntegration = false;
      #config = { };
      stdlib = ''
        use_flake() {
          watch_file flake.nix
          watch_file flake.lock
          eval "$(nix print-dev-env --profile "$(direnv_layout_dir)/flake-profile")"
        }
      '';
    };

    dconf.enable = lib.mkDefault false; # TODO: is this just broken?
  };
}
