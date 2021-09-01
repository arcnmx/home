{ config, lib, ... }: with lib; let
  cfg = config.programs.ncmpcpp;
in {
  config.programs.ncmpcpp = mkIf config.home.profiles.personal {
    enable = mkDefault true;
    mpdHost = mkIf config.services.mpd.enable "/run/user/1000/mpd/socket";
    settings = mapAttrs (_: mkDefault) {
      data_fetching_delay = false;
      playlist_disable_highlight_delay = 0;
      mouse_support = true;
      mouse_list_scroll_whole_page = false;
      cyclic_scrolling = false;
      seek_time = 10;
      external_editor = "vim";

      user_interface = "alternative";
      media_library_primary_tag = "album_artist";
      search_engine_display_mode = "columns";
      playlist_display_mode = "columns";
      browser_display_mode = "columns";
      autocenter_mode = false;
      centered_cursor = false;
      follow_now_playing_lyrics = true;

      titles_visibility = false;
      header_visibility = false;
      statusbar_visibility = false;

      colors_enabled = true;
      discard_colors_if_item_is_selected = false;
      header_window_color = 250;
      volume_color = 250;
      state_line_color = "cyan";
      state_flags_color = "cyan";
      statusbar_color = "yellow";
      # active_column_color = white # WARNING: Variable 'active_column_color' is deprecated and will be removed in 0.9 (replaced by current_item_inactive_column_prefix and current_item_inactive_column_suffix).
      current_item_inactive_column_prefix = "$(white)$r";
      current_item_inactive_column_suffix = "$/r$(end)";

      progressbar_color = "black";
      progressbar_elapsed_color = "blue";

      now_playing_suffix = "$7 ♫ $9";
      selected_item_prefix = " √ ";
      browser_playlist_prefix = "$2plist »$9 ";

      song_window_title_format = "%a - %t";
      song_columns_list_format = "(50)[white]{t|f:Title} (20)[yellow]{a} (20)[blue]{b} (7f)[cyan]{l}";
      song_library_format = "{$2%n.$9 }{$5%a $7»$9 }{$8%t}|{$8%f}";
      song_list_format = "{$5%a $7»$9 }{$8%t}|{$8%f}";
      #song_status_format = "$8%a$9 ✖ $2%t$9";
      #song_status_format = " $2%a $4⟫$3⟫ $8%t $4⟫$3⟫ $5%b ";
      progressbar_look = "▄▄ ";
    };
    bindings = [
      { key = "k"; command = "scroll_up"; }
      { key = "j"; command = "scroll_down"; }
      { key = "h"; command = "previous_column"; }
      { key = "l"; command = "next_column"; }

      { key = "ctrl-u"; command = "page_up"; }
      { key = "ctrl-d"; command = "page_down"; }

      { key = "0"; command = "move_home"; }
      { key = "g"; command = "move_home"; }
      { key = "G"; command = "move_end"; }

      { key = "n"; command = "next_found_item"; }
      { key = "N"; command = "previous_found_item"; }

      { key = "ctrl-g"; command = "jump_to_position_in_song"; }
      #{ key = "ctrl-G"; command = "jump_to_browser"; }
      #{ key = "ctrl-G"; command = "jump_to_playlist_editor"; }

      { key = "d"; command = "delete_playlist_items"; }
      { key = "d"; command = "delete_browser_items"; }
      { key = "d"; command = "delete_stored_playlist"; }

      { key = "w"; command = "save_playlist"; }

      { key = "H"; command = "volume_down"; }
      { key = "L"; command = "volume_up"; }
      { key = "ctrl-k"; command = "previous"; }
      { key = "ctrl-j"; command = "next"; }
      { key = "ctrl-h"; command = "seek_backward"; }
      { key = "ctrl-l"; command = "seek_forward"; }
      { key = "space"; command = "pause"; }

      { key = "y"; command = "select_item"; }
      { key = "V"; command = "reverse_selection"; }
      { key = "ctrl-v"; command = "remove_selection"; }
      { key = "A"; command = "add_selected_items"; }

      { key = "p"; command = "move_selected_items_to"; }
      { key = "K"; command = "move_selected_items_up"; }
      { key = "J"; command = "move_selected_items_down"; }

      { key = "a"; command = "add_item_to_playlist"; }
      { key = "+"; command = "add"; }
      { key = "-"; command = "load"; }
      { key = "D"; command = "clear_playlist"; }
      { key = "D"; command = "clear_main_playlist"; }
      { key = "C"; command = "crop_playlist"; }
      { key = "C"; command = "crop_main_playlist"; }

      { key = "x"; command = "next_screen"; }

      { key = "P"; command = "show_playlist"; }
      { key = "B"; command = "show_browser"; }
      { key = "B"; command = "change_browse_mode"; }
      { key = "S"; command = "show_search_engine"; }
      { key = "S"; command = "reset_search_engine"; }
      { key = "M"; command = "show_media_library"; }
      { key = "M"; command = "toggle_media_library_columns_mode"; }

      { key = "O"; command = "show_outputs"; }
      { key = "space"; command = "toggle_output"; }

      { key = "M"; command = "show_lyrics"; }
      { key = "r"; command = "refetch_lyrics"; }

      { key = "ctrl-l"; command = "update_database"; }

      # TODO: not yet supported by home-manager?
      #def_command "add" [deferred]
      #  add
    ];
  };
}
