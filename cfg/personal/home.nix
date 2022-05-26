{ base16, config, pkgs, lib, ... } @ args: with lib; let
  inherit (config.lib.file) mkOutOfStoreSymlink;
  mpc = pkgs.writeShellScriptBin "mpc" ''
    export MPD_HOST=${escapeShellArg config.programs.ncmpcpp.settings.mpd_host}
    ${pkgs.mpc_cli}/bin/mpc "$@"
  '';
  mplay = pkgs.writeShellScriptBin "mplay" ''
    COUNT=$#
    ${mpc}/bin/mpc add "$@" &&
      ${mpc}/bin/mpc play $(($(${mpc}/bin/mpc playlist | wc -l) - COUNT + 1))
  '';
  cfg = config.home.profileSettings.personal;
  vimNotmuchSettings = ''
    source ${./files/vimrc-notmuch}
    let g:notmuch_config_file='${config.home.sessionVariables.NOTMUCH_CONFIG}'
    let g:notmuch_html_converter='${pkgs.elinks}/bin/elinks --dump'
    let g:notmuch_attachment_dir='${config.xdg.userDirs.absolute.download}'
    let g:notmuch_view_attachment='xdg-open'
    let g:notmuch_sendmail_method='sendmail'
    let g:notmuch_sendmail_location='${pkgs.msmtp}/bin/msmtp'
    let g:notmuch_open_uri='firefox'
  '';
  vimCocSettings = ''
    source ${./files/vimrc-coc}
    let g:coc_node_path='${pkgs.nodejs}/bin/node'
  '';
  vimSettings = ''
    let g:Hexokinase_ftDisabled = ['notmuch-search']
    let g:Hexokinase_ftEnabled = ['html', 'css'] " TODO: not worth configuring properly right now
    let g:echodoc#enable_at_startup=1
    set statusline^=%{FugitiveStatusline()}
  '' + optionalString (!config.home.minimalSystem) ''
    function M2A()
      :%!${pkgs.pandoc}/bin/pandoc --columns=120 --wrap=preserve -f gfm+hard_line_breaks -t asciidoctor
      :set ft=asciidoc
    endfunction
    function A2M()
      " workaround for https://github.com/jgm/pandoc/issues/8011
      :%!${pkgs.asciidoctor}/bin/asciidoctor -b docbook5 - | sed -e 's/10063;/9744;/' -e 's/10003;/9746;/g' | ${pkgs.pandoc}/bin/pandoc --columns=120 --wrap=none -f docbook -t gfm+hard_line_breaks | sed -e 's/^-   /- /'
      :set ft=markdown
    endfunction
    command M2A call M2A()
    command A2M call A2M()
  '';
  vimPlugins = with pkgs.vimPlugins; [
    notmuch-vim
    editorconfig-vim
    vim-easymotion
    vim-fugitive
    vim-hexokinase
    jsonc-vim
    echodoc-vim
  ];
  vimCocPlugins = with pkgs.vimPlugins; [
    coc-json
    coc-yaml
    coc-rust-analyzer
    coc-git
    coc-yank
    coc-tsserver
    coc-lua
    coc-pyright
    coc-spell-checker
    coc-smartf
    coc-markdownlint
    coc-cmake
    coc-html coc-css
    coc-explorer
    coc-lists
  ];
in {
  imports = [
    ./ncmpcpp.nix
    ./email.nix
  ];
  options = {
    home.profileSettings.personal = {
      primaryHost = mkOption {
        type = types.nullOr types.str;
        default = null;
      };
      isPrimary = mkOption {
        type = types.bool;
        default = config.home.hostName == cfg.primaryHost;
      };
    };
  };

  config = {
    home.file = with pkgs.arc.packages.personal.task-blocks; {
      ".task/hooks/on-exit.task-blocks".source = on-exit;
      ".task/hooks/on-add.task-blocks".source = on-add;
      ".task/hooks/on-modify.task-blocks".source = on-modify;
      ".electrum".source = mkOutOfStoreSymlink "${config.xdg.configHome}/electrum/";
    };
    home.packages = with pkgs; [
      git-remote-gcrypt git-revise git-annex git-annex-remote-b2
      gnupg
      pass-arc
      bitwarden-cli
      weechat-matrix
      playerctl
      awscli2
      physlock
      travis
      radare2
      electrum-cli
      jq yq
      lorri
      mpc mplay
      pinentry.curses
      #TODO: benc bsync snar-snapper
    ];
    home.profileSettings.personal = {
      primaryHost = "shanghai";
    };
    home.shell = {
      aliases = {
        mail = mkIf config.programs.notmuch.enable "vim +NotMuch";
        vit = "task vit";
        task3s = "task rc.context=3s";
        taskwork = "task rc.context=work";
        taskfun = "task rc.context=fun";
        taskrm = "task rc.confirmation=no delete";
      };
      deprecationAliases = {
        ncpamixer = "pulsemixer";
      };
      functions = {
        mradio = ''
          mplay http://shanghai:32101
        '';
        lorri-init = ''
          echo 'use ${if config.services.lorri.useNix || !config.services.lorri.enable then "nix" else "lorri"}' > .envrc
        '' + optionalString config.services.lorri.enable ''
          for nixfile in $PWD/shell.nix; do # default.nix?
            if [[ -e $nixfile ]]; then
              ${config.services.lorri.package}/bin/lorri ping_ $nixfile
              break
            fi
          done
        '' + ''
          direnv allow
        '';
        iclip = ''
          local ICLIP_DIR=/run/iclip
          local ICLIP_FILE=$ICLIP_DIR/_clip.txt ICLIP_TMP
          if [[ $1 = -o ]]; then
              cat "$ICLIP_DIR/$(ls -rt "$ICLIP_DIR" | tail -n 1)"
          elif [[ $1 = -d ]]; then
              rm "$ICLIP_DIR/"*
          else
              ICLIP_TMP=$(mktemp --tmpdir iclip.XXXXXXXXXX)
              cat > "$ICLIP_TMP" && mv "$ICLIP_TMP" "$ICLIP_FILE"
          fi
        '';
        task = ''
          local TASK_EXEC=${pkgs.taskwarrior}/bin/task
          if [[ ''${1-} = vit ]]; then
            shift
            TASK_EXEC=${pkgs.vit}/bin/vit
          fi
          local TASK_DIR=$XDG_RUNTIME_DIR/taskwarrior
          mkdir -p "$TASK_DIR" &&
            (cd "$TASK_DIR" && "$TASK_EXEC" "$@")
        ''; # NOTE: link theme to $TASK_DIR/theme and `include ./theme` - can be conditional on $(theme isDark)
        tasks = ''
          #local _TASK_REPORT=next
          local _TASK_REPORT=
          if [[ $# -gt 0 ]]; then
              _TASK_REPORT=$1
              shift
          fi
          local _TASK_OPTIONS=(rc.defaultheight=$LINES rc.defaultwidth=$COLUMNS rc._forcecolor=yes limit:0)
          {
              if [[ -z $_TASK_REPORT ]]; then
                  #task "''${_TASK_OPTIONS[@]}" next "$@"
                  task "''${_TASK_OPTIONS[@]}" short "$@"
                  task "''${_TASK_OPTIONS[@]}" longterm "$@"
                  task "''${_TASK_OPTIONS[@]}" upcoming "$@"
              else
                  task "''${_TASK_OPTIONS[@]}" "$_TASK_REPORT" "$@"
              fi
          } 2> /dev/null | ''${PAGER-less -R}
        '';
      } // optionalAttrs pkgs.hostPlatform.isLinux {
        lorri-status = ''
          ${config.systemd.package}/bin/systemctl --user status lorri.service
        '';
        lorri-log = ''
          ${config.systemd.package}/bin/journalctl --user -fu lorri.service
        '';
      };
    };
    #services.lorri.enable = true;
    services.gpg-agent = {
      enable = true;
      enableExtraSocket = true;
      enableScDaemon = false;
      enableSshSupport = true;
      pinentryFlavor = mkDefault null;
      extraConfig = mkMerge [
        "auto-expand-secmem 0x30000" # otherwise "gpg: public key decryption failed: Cannot allocate memory"
        "pinentry-timeout 30"
        "allow-loopback-pinentry"
        "no-allow-external-cache"
      ];
      #defaultCacheTtl = 31536000; maxCacheTtl = 31536000; defaultCacheTtlSsh = 31536000; maxCacheTtlSsh = 31536000; # doing a bad remove me later thanks
    };
    services.mpd = {
      enable = true;
      network.startWhenNeeded = true;
      package = pkgs.mpd-youtube-dl;
      dbFile = "${config.services.mpd.dataDir}/mpd.db";
      musicDirectory = config.xdg.userDirs.absolute.music;
      extraConfig = ''
        restore_paused "yes"
        metadata_to_use "artist,artistsort,album,albumsort,albumartist,albumartistsort,title,track,name,genre,date,composer,performer,comment,disc,musicbrainz_artistid,musicbrainz_albumid,musicbrainz_albumartistid,musicbrainz_trackid,musicbrainz_releasetrackid"
        auto_update "yes"
        max_output_buffer_size "65536"

        follow_outside_symlinks "yes"
        follow_inside_symlinks "yes"

        default_permissions "read"

        audio_output {
          type "pulse"
          name "speaker"
        }
        input {
          plugin "youtube-dl"
          executable "${pkgs.yt-dlp}/bin/yt-dlp"
        }
      '';
    };
    services.mpdris2.enable = mkDefault config.services.mpd.enable;
    systemd.user.services.mpdris2 = mkIf config.services.mpdris2.enable {
      Install = mkForce {
        WantedBy = [ "mpd.service" ];
      };
      Unit = {
        PartOf = [ "mpd.service" ];
      };
    };
    programs.zsh = {
      dirHashes = {
        gen = "${config.xdg.userDirs.documents}/gensokyo";
        fork = "${config.xdg.userDirs.documents}/fork";
        nix = "${config.xdg.userDirs.documents}/nix";
      };
    };
    programs.git = {
      package = pkgs.git;
      extraConfig = {
        gcrypt = {
          require-explicit-force-push = false;
        };
      };
    };
    programs.gh = {
      enable = !config.home.minimalSystem;
      settings.git_protocol = "ssh";
    };
    programs.bitw.enable = mkDefault (!config.home.minimalSystem);
    programs.buku = {
      enable = !config.home.minimalSystem;
      bookmarks = {
        howoldis = {
          title = "NixOS Channel Freshness";
          url = "https://status.nixos.org/";
          tags = [ "nix" "nixos" "channels" ];
        };
        nixexprs-ci = {
          title = "nixexprs CI";
          url = "https://github.com/arcnmx/nixexprs/actions";
          tags = [ "arc" "ci" "nix" "nixexprs" "actions" ];
        };
      };
    };
    programs.ncpamixer = {
      enable = false;
      keybinds = {
        "48" = "set_volume_100"; # 0
        "96" = "set_volume_0"; # `
        "74" = "tab_next"; # J
        "75" = "tab_prev"; # K
      };
    };
    programs.pulsemixer = {
      enable = config.home.nixosConfig.hardware.pulseaudio.enable or pkgs.hostPlatform.isLinux || config.home.nixosConfig.services.pipewire.enable or false;
      configContent.keys = {
        next-mode = "J";
        prev-mode = "K";
        mute = "m, `";
      };
    };
    programs.filebin = {
      enable = !config.home.minimalSystem;
      extraConfig = ''
        AWS_ACCESS_KEY_ID=$(bitw get tokens/aws-filebin -f aws_access_key_id)
        AWS_SECRET_ACCESS_KEY=$(bitw get tokens/aws-filebin -f aws_secret_access_key)
        FILEBIN_S3_BUCKET=$(bitw get tokens/aws-filebin -f s3_bucket_name)
        FILEBIN_BOXCAR_KEY=$(bitw get tokens/boxcar-filebin -f notes)
      '';
    };
    programs.vim = {
      plugins = vimPlugins ++ optionals config.programs.neovim.coc.enable (
        singleton pkgs.vimPlugins.coc-nvim ++ vimCocPlugins
      );
      extraConfig = mkMerge [
        (mkIf config.programs.notmuch.enable vimNotmuchSettings)
        (mkIf config.programs.neovim.coc.enable ''
          ${vimCocSettings}
          let g:coc_config_home=$XDG_CONFIG_HOME . '/vim/coc'
        '')
        vimSettings
      ];
    };
    programs.neovim = {
      enable = true;
      plugins = vimPlugins ++ optionals config.programs.neovim.coc.enable vimCocPlugins;
      extraConfig = mkMerge [
        (mkIf config.programs.notmuch.enable vimNotmuchSettings)
        (mkIf config.programs.neovim.coc.enable vimCocSettings)
        ''
          ${vimSettings}

          let g:echodoc#type = 'floating'
        ''
      ];
      coc = {
        enable = mkDefault (!config.home.minimalSystem);
        settings = {
          languageserver = {
            efm = {
              command = "${pkgs.efm-langserver}/bin/efm-langserver";
              args = [];
              filetypes = [ "vim" ];
            };
            nix = {
              command = "${pkgs.rnix-lsp}/bin/rnix-lsp";
              args = [];
              filetypes = ["nix"];
              cwd = "./";
              initializationOptions = {
              };
              settings = {
              };
            };
          };
          "coc.preferences.extensionUpdateCheck" = "never";
          #"coc.preferences.watchmanPath" = "${pkgs.watchman}/bin/watchman"; # TODO: segfaults constantly, see https://github.com/NixOS/nixpkgs/issues/156177
          "suggest.timeout" = 1000;
          "suggest.maxPreviewWidth" = 120;
          "suggest.enablePreview" = true;
          "suggest.echodocSupport" = true;
          "suggest.minTriggerInputLength" = 2;
          "suggest.acceptSuggestionOnCommitCharacter" = true;
          "suggest.snippetIndicator" = "►";
          "diagnostic.checkCurrentLine" = true;
          "diagnostic.enableMessage" = "jump";
          "list.nextKeymap" = "<A-j>";
          "list.previousKeymap" = "<A-k>";
          # list.normalMappings, list.insertMappings
          # coc.preferences.formatOnType, coc.preferences.formatOnSaveFiletypes
          "npm.binPath" = "${pkgs.coreutils}/bin/false"; # whatever it wants npm for, please just don't
          "codeLens.enable" = true;
          "rust-analyzer.server.path" = "rust-analyzer";
          "rust-analyzer.updates.prompt" = "neverDownload";
          "rust-analyzer.notifications.cargoTomlNotFound" = false;
          "rust-analyzer.cargo.runBuildScripts" = true;
          "rust-analyzer.procMacro.enable" = true;
          "rust-analyzer.experimental.procAttrMacros" = true;
          "rust-analyzer.completion.addCallParenthesis" = true; # consider using this?
          "rust-analyzer.hover.linksInHover" = true;
          "rust-analyzer.rustfmt.enableRangeFormatting" = true;
          "rust-analyzer.lens.methodReferences" = true;
          "rust-analyzer.assist.allowMergingIntoGlobImports" = false;
          "rust-analyzer.diagnostics.disabled" = [
            "inactive-code" # it has strange cfg support..?
          ];
          # NOTE: per-project overrides go in $PWD/.vim/coc-settings.json
        };
      };
    };
    programs.kakoune = {
      config.hooks = [
        {
          name = "WinSetOption";
          option = "filetype=(rust|yaml|nix|markdown)";
          commands = "lsp-enable-window";
        }
      ];
      pluginsExt = with pkgs.kakPlugins; [
        kak-lsp
        kak-tree
      ];
    };
    programs.rustfmt = {
      package = pkgs.rustfmt-nightly;
    };
    programs.weechat = {
      enable = true;
      homeDirectory = "${config.xdg.dataHome}/weechat";
      plugins.python = {
        enable = true;
        packages = [ "weechat-matrix" ];
      };
      autosort = {
        enable = true;
        # TODO: change signals from defaults?
        rules = let
          script_or_plugin = "\${if:\${script_name}?\${script_name}:\${plugin}}";
        in mkMerge [
          (mkBefore [
            # core/plugins at top...
            "\${if:\${buffer.full_name}!=core.weechat}" # core_first
            "\${info:autosort_order,\${info:autosort_escape,${script_or_plugin}},core,*}"
            "\${if:\${buffer.full_name}!=irc.irc_raw}" # irc_raw_first
            "\${info:autosort_order,\${type},server,*}"
          ])
          (mkAfter [
            "\${info:autosort_order,\${type},*,channel,private}"
            "\${cut:4,,\${rev:\${buffer.localvar_room_id}}}" # lazy rough server sort .-.
            "\${info:autosort_replace,#,,\${info:autosort_escape,\${buffer.short_name}}}"
            "\${info:autosort_replace,#,,\${info:autosort_escape,\${buffer.name}}}"
            "\${buffer.full_name}"
          ])
        ];
        shortNames.last = mkAfter [
          "perl.highmon"
        ];
      };
      scripts = with pkgs.weechatScripts; [
        weechat-matrix
        vimode-develop
        weechat-go buffer_autoset unread_buffer
        highmon weechat-notify-send
        auto_away colorize_nicks urlgrab
        emoji
      ];
      init = mkMerge [
        # make a new split window for highmon
        ''
          /window splith +10
          /window 2
          /buffer perl.highmon
          /window 1
          /buffer hide perl.highmon
        ''
      ];
      config = with base16.map.ansiStr; let
        nothighmon.conditions = "\${window.buffer.full_name} != perl.highmon";
        # base16-shell colour names
      in {
        urlgrab.default.copycmd = "${pkgs.xsel}/bin/xsel -i";
        # TODO: /fset *color* and find the sections you've missed
        fset = {
          color = {
            line_selected_bg1 = base02;
            line_selected_bg2 = base07;
          };
        };
        matrix = {
          network = {
            max_backlog_sync_events = 30;
            lazy_load_room_users = true; # not sure which way to go on this
            autoreconnect_delay_max = 60;
            lag_min_show = 1000;
            # TODO: typing_notice_conditions and read_markers_conditions
          };
          color = {
            #error_message_bg
            error_message_fg = base08;
            #quote_bg
            quote_fg = base0B;
            #unconfirmed_message_bg
            unconfirmed_message_fg = base03; # 0F?
            #untagged_code_bg
            untagged_code_fg = base0C; # 0F?
          };
          look = {
            bar_item_typing_notice_prefix = "... ";
          };
        };
        buflist = {
          format = {
            indent = ""; # default "  "
            buffer_current = "\${color:,${base02}}\${format_buffer}";
            hotlist = " \${color:${base0D}}(\${hotlist}\${color:${base0D}})";
            hotlist_highlight = "\${color:${base0E}}";
            hotlist_low = "\${color:${base03}}";
            hotlist_message = "\${color:${base08}}";
            hotlist_none = "\${color:${base05}}";
            hotlist_private = "\${color:${base09}}";
            hotlist_separator = "\${color:${base04}},";
            number = "\${color:${base09}}\${number}\${if:\${number_displayed}?.: }";
            # TODO: truncation via buffer = "\${format_number}\${cut:20,...,\${format_nick_prefix}\${format_name}}"
          };
        };
        weechat = {
          bar = {
            buflist = {
              size_max = 24;
              color_delim = base0C;
            };
            nicklist = {
              size_max = 18;
              color_delim = base0C;
            };
            input = {
              items = "[input_prompt]+(away),[input_search],[input_paste],input_text,[vi_buffer]";
              color_delim = base0C;
              inherit (nothighmon) conditions;
            };
            status = {
              color_delim = base0C;
              color_bg = base01;
              color_fg = base04;
              items = "[time],mode_indicator,[buffer_last_number],[buffer_plugin],buffer_number+:+buffer_name+(buffer_modes)+{buffer_nicklist_count}+matrix_typing_notice+buffer_zoom+buffer_filter,scroll,[lag],[hotlist],completion,cmd_completion";
              inherit (nothighmon) conditions;
            };
            title = {
              color_delim = base0C;
              color_bg = base01;
              color_fg = base04;
              inherit (nothighmon) conditions;
            };
            highmon = {
              position = "top";
              color_delim = base0A;
            };
          };
          look = {
            buffer_time_format = "\${color:${base06}}%H:\${color:${base05}}%M:\${color:${base04}}%S";
            bar_more_down = "▼";
            bar_more_left = "◀";
            bar_more_right = "▶";
            bar_more_up = "▲";
            prefix_join = "→";
            prefix_quit = "←";
            #prefix_error = "⚠";
            prefix_suffix = "╡";
            prefix_network = "ℹ ";
            prefix_same_nick = "|->";
            read_marker_string = "─";
            buffer_notify_default = "message";
            scroll_amount = 25;
          };
          #filter = {
          #  irc_smart = "on;*;irc_smart_filter;*";
          #  joinquit = "on;*;irc_join,irc_part,irc_quit;*";
          #  irc_join_names = "on;*;irc_366,irc_332,irc_333,irc_329,irc_324;*"; # When we join a channel, a lot of information is spit out, most of which is redundant
          #};
          color = {
            bar_more = base0E;
            chat = base05;
            chat_bg = "default";
            chat_buffer = base08;
            chat_channel = base08;
            chat_day_change = base03;
            chat_delimiters = base06;
            chat_highlight = base0E;
            chat_highlight_bg = "default";
            chat_host = base0A;
            chat_inactive_buffer = base0F;
            chat_inactive_window = base0F;
            chat_nick = base08;
            chat_nick_colors = "${base08},${base09},${base0A},${base0B},${base0C},${base0D},${base0E}";
            chat_nick_offline = base0F;
            #chat_nick_offline_highlight = ?
            chat_nick_offline_highlight_bg = "default";
            chat_nick_other = base0C;
            chat_nick_prefix = base0A;
            chat_nick_self = base06;
            chat_nick_suffix = base0F;
            chat_prefix_action = base0D;
            chat_prefix_buffer = base0B;
            chat_prefix_buffer_inactive_buffer = base0F;
            chat_prefix_error = base08;
            chat_prefix_join = base0B;
            chat_prefix_more = base0D;
            chat_prefix_network = base0A;
            chat_prefix_quit = base0F;
            chat_prefix_suffix = base04;
            chat_read_marker = base03;
            #chat_read_marker_bg = base00;
            chat_read_marker_bg = base01;
            chat_server = base0A;
            #chat_tags
            chat_text_found = base09;
            chat_text_found_bg = base02;
            chat_time = base03;
            chat_time_delimiters = base05;
            chat_value = base09;
            chat_value_null = base0E;
            emphasized = base04;
            emphasized_bg = base02;
            #input_actions = ?
            #input_text_not_found = ?
            item_away = base03;
            nicklist_away = base03;
            nicklist_group = base0D;
            separator = base04;
            status_count_highlight = base09;
            status_count_msg = base08;
            status_count_other = base04;
            status_count_private = base09;
            status_data_highlight = base09;
            status_data_msg = base04;
            status_data_other = base04;
            status_data_private = base09;
            status_filter = base05;
            status_more = base0E;
            status_mouse = base04;
            status_name = base04;
            status_name_ssl = base04;
            status_nicklist_count = base04;
            status_number = base04;
            status_time = base05;
          };
        };
        irc = {
          look = {
            smart_filter = true;
            temporary_servers = true;
            color_nicks_in_nicklist = true;
          };
          color = {
            input_nick = base08;
            item_channel_modes = base0C;
            #item_lag_counting = ?;
            #item_lag_finished = ?;
            item_nick_modes = base0C;
            #message_chghost = ?;
            message_join = base0B;
            message_quit = base08;
            #mirc_remap, nick_prefixes
            notice = base0F;
            reason_quit = base0F;
            topic_current = base04;
            topic_new = base06;
            topic_old = base0F;
          };
        };
        plugins = {
          var.python.vimode = {
            copy_clipboard_cmd = "${pkgs.xsel}/bin/xsel -b";
            paste_clipboard_cmd = "${pkgs.xsel}/bin/xsel -ob";
            imap_esc_timeout = "100";
            search_vim = true;
            user_mappings = builtins.toJSON {
              "`," = "a/go<CR>";
              "," = "/buffer #{1}<CR>"; # TODO: start getting used to a different key for this instead?
              "``" = "/input jump_last_buffer_displayed<CR>";
              "`n" = "/input jump_smart<CR>";
              "k" = "/input history_previous<CR>";
              "j" = "/input history_next<CR>";
              "p" = "a/input clipboard_paste<ICMD><ESC>";
              "P" = "/input clipboard_paste<CR>";
              #"u" = "/input undo<CR>";
              #"\\x01R" = "/input redo<CR>";
              "\\x01K" = "/buffer move -1<CR>";
              "\\x01J" = "/buffer move +1<CR>";
            };
            user_mappings_noremap = builtins.toJSON {
              "\\x01P" = "p";
              "/" = "i/";
            };
            user_search_mapping = "?";
            mode_indicator_cmd_color_bg = base01;
            mode_indicator_cmd_color = base04;
            mode_indicator_insert_color_bg = base01;
            mode_indicator_insert_color = base04;
            mode_indicator_normal_color_bg = base01;
            mode_indicator_normal_color = base04;
            mode_indicator_replace_color_bg = base01;
            mode_indicator_replace_color = base0E;
            mode_indicator_search_color_bg = base0A;
            mode_indicator_search_color = base04;
            no_warn = true;
          };
          var.python.go = {
            short_name = true;
            use_core_instead_weechat = true;
            fuzzy_search = true;
            sort = "hotlist,number,beginning";
            #auto_jump = true;
          };
          var.python.notify_send = {
            min_notification_delay = 0;
            max_length = 0;
            timeout = 0;
            urgency = "critical";
            icon = "chat-message-new-symbolic.symbolic";
          };
          var.perl.highmon = {
            output = "buffer";
            short_names = true;
            merge_private = true;
            alignment = "nchannel,nick";
          };
        };
      };
    };
    programs.taskwarrior = let
      theme = import ./taskwarrior-theme.nix {
        inherit pkgs lib base16;
      };
    in {
      enable = true;
      dataLocation = "${config.xdg.dataHome}/task";
      activeContext = "home";
      extraConfig = ''
        include ${theme}
      '';
      contexts = {
        home = "(project.not:work and project.not:games and project.not:fun and project.not:home.shopping.) or +escalate";
        fun = "project:fun";
        work = "project:work";
        shop = "project:home.shopping";
        "3s" = "project:games.3scapes";
      };
      aliases = {
        "3s" = "project:games.3scapes";
        ms2 = "project:games.maplestory2";
        annoate = "annotate";
        undelete = "modify status:pending end:"; # name this restore instead?
      };
      userDefinedAttributes = {
        priority = { # 0-9 priority, where default/empty is around 2.5
          label = "Priority";
          type = "string";
          values = [
            { value = "9"; color.foreground = "color255"; urgencyCoefficient = "8.0"; }
            { value = "8"; color.foreground = "color255"; urgencyCoefficient = "7.0"; }
            { value = "7"; color.foreground = "color255"; urgencyCoefficient = "6.0"; }
            { value = "6"; color.foreground = "color245"; urgencyCoefficient = "5.0"; }
            { value = "5"; color.foreground = "color245"; urgencyCoefficient = "4.0"; }
            { value = "4"; color.foreground = "color245"; urgencyCoefficient = "3.0"; }
            { value = "3"; color.foreground = "color245"; urgencyCoefficient = "2.0"; }
            { value = ""; }
            { value = "2"; color.foreground = "color250"; urgencyCoefficient = "-1.0"; }
            { value = "1"; color.foreground = "color250"; urgencyCoefficient = "-2.0"; }
            { value = "0"; color.foreground = "color250"; urgencyCoefficient = "-3.0"; }
          ];
        };
        blocks = { # blocks: hook
          type = "string";
          label = "Blocks";
        };
        blocked = { # blocked: hook
          type = "string";
          label = "Blocked";
        };
      };
      reports = {
        short = {
          description = "Abbreviated next report";
          filter = "status:pending limit:page +READY -longterm";
          columns = [
            { label = "ID"; id = "id"; }
            { label = "Active"; id = "start"; format = "age"; }
            { label = "Due"; id = "due"; format = "relative"; }
            { label = "Until"; id = "until"; format = "remaining"; }
            { label = "Description"; id = "description"; format = "count"; }
            { label = "Project"; id = "project"; }
            { label = "Tags"; id = "tags"; }
            { label = "Deps"; id = "depends"; }
            { label = "Urg"; id = "urgency"; sort = {
              priority = 0;
              order = "descending";
            }; }
          ];
        };
        longterm = {
          description = "Long-term tasks";
          filter = "status:pending limit:page +READY +longterm";
          columns = [
            { label = "ID"; id = "id"; }
            { label = "Active"; id = "start"; format = "age"; }
            { label = "Due"; id = "due"; format = "relative"; }
            { label = "Until"; id = "until"; format = "remaining"; }
            { label = "Description"; id = "description"; format = "count"; }
            { label = "Project"; id = "project"; }
            { label = "Tags"; id = "tags"; }
            { label = "Deps"; id = "depends"; }
            { label = "Urg"; id = "urgency"; sort = {
              priority = 0;
              order = "descending";
            }; }
          ];
        };
        upcoming = {
          description = "Abbreviated waiting report";
          filter = "+WAITING or (status:pending and -READY)";
          columns = [
            { label = "ID"; id = "id"; }
            { label = "A"; id = "start"; format = "active"; }
            { label = "Age"; id = "entry"; format = "age"; sort = {
              priority = 2;
              order = "ascending";
            }; }
            { label = "P"; id = "priority"; }
            { label = "Project"; id = "project"; }
            { label = "Tags"; id = "tags"; }
            { label = "Wait"; id = "wait"; sort = {
              priority = 1;
              order = "ascending";
            }; }
            { label = "Left"; id = "wait"; format = "remaining"; }
            { label = "S"; id = "scheduled"; format = "remaining"; }
            { label = "Due"; id = "due"; sort = {
              priority = 0;
              order = "ascending";
            }; }
            { label = "Until"; id = "until"; }
            { label = "Description"; id = "description"; format = "count"; }
          ];
        };
      };

      config = {
        default.command = "short";
        list.all = {
          projects = "yes";
          tags = "yes";
        };
        complete.all = {
          projects = "yes";
          tags = "yes";
        };
        reserved.lines = "2";
        recurrence = if cfg.isPrimary then {
          confirmation = "no";
        } else "off"; # https://github.com/GothenburgBitFactory/taskserver/issues/46
        bulk = 7;
        nag = "";

        verbose = ["header" "footnote" "label" "new-id" "new-uuid" "affected" "edit" "special" "project" "unwait" "recur"]; # removed: blank, override, sync

        urgency = {
          blocking.coefficient = "1.0";
          annotations.coefficient = "0.0";
          scheduled.coefficient = "0.5";

          user.tag = {
            commit.coefficient = "10.0";
            remote.coefficient = "-0.9";
            routine.coefficient = "9.0";
            review.coefficient = "2.0";
            escalate.coefficient = "0.5";
            READY.coefficient = "30.0";
          };
        };
      };
    };

    xdg.configFile = {
      "electrum/.keep".text = "";
      "efm-langserver/config.yaml".text = ''
        languages:
          markdown:
            lint-command: '${pkgs.nodePackages.markdownlint-cli}/bin/markdownlint -s'
            lint-stdin: true
            lint-formats:
            - '%f: %l: %m'
          vim:
            lint-command: '${pkgs.vim-vint}/bin/vint -'
            lint-stdin: true
          yaml:
            lint-command: '${pkgs.yamllint}/bin/yamllint -f parsable -'
            lint-stdin: true
            lint-formats:
            - '%f:%l:%c: %m'
      '';
      "vim/coc/coc-settings.json" = mkIf (config.programs.vim.enable && config.programs.neovim.coc.enable) {
        text = builtins.toJSON config.programs.neovim.coc.settings;
      };
      "kak-lsp/kak-lsp.toml".source = pkgs.substituteAll {
        inherit (pkgs) efm-langserver rnix-lsp;
        #inherit (pkgs.nodePackages) vscode-html-languageserver-bin vscode-css-languageserver-bin vscode-json-languageserver;
        src = ./files/kak-lsp.toml;
      };
    };

    programs.ssh.strictHostKeyChecking = "accept-new";
    services.sshd.authorizedKeys = [
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCik1rxKNKDBcIQrFrleGXlz/SwJXmC7TjAHqO3QXe0sIR4/egYhQlKSWLWiV/HviMJ0RNuBMNG6yfNpItNAvkKT9nExxyRFC4PAkYf4mBk6x4Re9hAE9FM9KAe7cFBx/+xD6VxJYGEoKyWejuCE16Tn48G7TEQyxr0bJwO9jL+LKAS+/Za3mx2kyKZNmn7b4Roa9uWeJDFpmzqsOmvxiLpF5sQ4EyKaiifyVUKaPGdoonVKXQMmnzyBP/e553raLYV13bGzPKBq8UnRHKmVbNSotIrGZ/X/PBT/Y8jRRZhba2hhai8ofGtkIhzdPWdTs30qlBrbRa2nEeVEVC6mKzv+gMtb0kiNOxb4ceKUpAntMUr2aCjsF1OTkROOqbLg8nTHAIM9JHFDNZmzDGa7kjtn4c8V4X/beydTAWNDClLG9CWwjG+X+ZpGsuOFX/ke62pcj44tK+qm1XckdX1HyCXrG7R4AeOyqZ8uXla5QoUgsK8qEa1ZFbRgQQtC595DvsQosfnJXrKuDurEeBfl/Ew4ugIHQvHioeAUAxG80WYJHyCfdh1V0a5fB19LEiWDZyy7uUqsuJYG8LWTrpJaM/PTbUaFI4No5vhSCKjmbFalJRhyGMbrhr+x7jnW1JRXS6lkvoDbJlUPLBRg63t6cZeXWCdMcXo1Me9Octc2XSSLQ== arc@shanghai"
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDMBsg/h3ITy/2u1IpTpazEMU+hKaThjC7wDPQzIKvicw6Hf+O7M8uw6DSFXAXhjygLvonhKhlVt6qKzrSJrKZDPewT/hkgFU2Zvj8JwWzSJKg9SYR6v0L1GYF2gB1K/QKNrXDxT0yoov/NDlN1lkVyYM9IMDRXVXx5SkojffMv9YC6NBZfOeaEmkKY3VCg5tePUF5limp9ipBzqjjIitDmNWBV/ID2paV/SIasGMfUFtipO5r8Bg4Wgv5sJPCWE82iYhZdJJkfHr8vn7M7ITMCQ00daSZlu2McCFkff+ZMe/wejX5xxyOXx9xI2yomzN77rMSl45pBp8MnHIigJ0zRiMSHfjpDkwVQiaMdMG6bti7wRbEw6fKWLHcRqnZ3sWMxNLNnSO8WGdAXt6WIPJ2IBSSp/XmDxFu30Ag9soOqprqTLVXzxfdj0vLAPdMRQI2LuVL4wNfXS7FJxiOs9oQFvxdaxmqxRyry3fafl2Z5epdgw3dgu2G7fkvy9NEuoFoZfYyNVFkIsJ/AktyFvr9ajimN1xfuyIlXXmZJRqoMQ8gZY+Qcguug2g9IhjRyVOglQiQp1V/JETtpScOFuD2xpwLTZ2Y3Ij21+XOnrI88Izcox+QAQvAyHGfoPwG5Zwj2A0gT+c9xaAEH+nQOyZ6xp5uY+7cpN/F0Z0XDRBWnvw== arc@shanghai-tan"
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCvdvIjXlLTpG2QlMi1kGYfgPXCDIsDM1Ldn4uPO3kz+uEJEgSrqVuKD71VAEZfN93HVZ4BoBTrjXC+jc0nSZjUgccCdo9aSZ87JbdocivNxwXxy9c/0B4+WU9+NB16VpVX+t43xgJxKfV9TW2QOLE0h0MMJizCsyX9rFMF4EOIR3TYe8Mm8x2L6axP4SZ7X+2aEyWg7VcEjzheKWvu+C4/B0c4D1/WtHcTrfy4/2urjvgYEXw5UVz7KOIXR0jIk2cvePOrjppDy8TjJxcm3zkFT4ZYuACWDiqfVZKuqAFI89kZ6fufbbHR1RilfHiehnPyzGj7KgPtwSgbxPJ9yvwX iphonese-prompt"
    ];
  };
}