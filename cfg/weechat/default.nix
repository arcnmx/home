{ base16, config, pkgs, lib, ... } @ args: with lib; {
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
  home.packages = with pkgs; [
    weechat-matrix
  ];
}
