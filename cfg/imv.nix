{ config, lib, ... }: with lib; {
  programs.imv = {
    enable = true;
    config = {
      scaling_mode = "shrink";
      suppress_default_binds = true;
    };
    binds = {
      "<Ctrl+0>" = "zoom actual";
      "<Ctrl+minus>" = "zoom -10";
      "<Ctrl+equal>" = "zoom 10";
      "<Ctrl+h>" = "prev";
      "<Ctrl+l>" = "next";
      O = "overlay";
      "<space>" = "center";
      "<Return>" = "toggle_playing";
      "<greater>" = "rotate by 90";
      "<less>" = "rotate by -90";

      # default bindings...
      q = "quit";
      "<Left>" = "prev 1";
      "<Right>" = "next 1";
      gg = "goto 1";
      G = "goto -1";
      j = "pan 0 10";
      k = "pan 0 -10";
      h = "pan -10 0";
      l = "pan 10 0";
      x = "close";
      f = "fullscreen";
      #p = "print to stdout"; # can't find this one
      s = "scaling next";
      S = "upscaling next";
      r = "reset";
      "<period>" = "next_frame";
      t = "slideshow +1";
      T = "slideshow -1";
    };
  };
  home.shell = mkIf config.programs.imv.enable {
    functions.imv = ''
      command imv "$@" &
    '';
    deprecationAliases.feh = "imv";
  };
}
