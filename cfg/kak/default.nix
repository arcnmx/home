{ pkgs, config, lib, ... }: with lib; {
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
}
