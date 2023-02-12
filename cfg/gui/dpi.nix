{ options, nixosConfig, config, lib, ... }@args: with lib; let
  cfg = nixosConfig.hardware.display;
  isHome = options ? home.homeDirectory;
  nixosConfig = if isHome then args.nixosConfig else config;
  libGUI = {
    size = sz: {
      str ? !float && !int
    , float ? false
    , int ? false
    , qt ? false
    , gtk ? qt
    , font ? !gtk || !isHome || !config.gtk.enable
    , norm ? [ ]
    , round ? int
    }: let
      result = flip pipe (
        optional font (size: size * cfg.fontScale)
        ++ flip map (toList norm) (norm: {
          gtk = size: size / config.gtk.dpiScale;
          font = size: size / cfg.fontScale;
          dpi = size: size / cfg.dpiScale;
          pt = size: size * cfg.dpi / 96.0;
        }.${norm})
        ++ optional round lib.round
        ++ optional float lib.toFloat
      ) (cfg.dpiScale * sz);
    in if str then numString result else result;
  };
in {
  options = with types; {
    hardware.${if isHome then null else "display"} = {
      dpi = mkOption {
        type = types.float;
        default = if isHome then nixosConfig.hardware.display.dpi else 96.0;
      };
      dpiScale = mkOption {
        type = types.float;
        default = if isHome then nixosConfig.hardware.display.dpi else 1.0;
      };
      fontScale = mkOption {
        type = types.float;
        default = if isHome then nixosConfig.hardware.display.dpi else 1.0;
      };
    };
    gtk = {
      dpiScale = mkOption {
        type = types.float;
        default = if isHome then nixosConfig.gtk.dpiScale else cfg.fontScale;
      };
    };
  };
  config = if isHome then {
    home.sessionVariables = mkMerge [
      (mkIf (config.gtk.enable && config.gtk.dpiScale != 1.0) {
        GDK_DPI_SCALE = numString config.gtk.dpiScale;
      })
      (mkIf (config.gtk.dpiScale != 1.0) {
        QT_FONT_DPI = numString (cfg.dpi * config.gtk.dpiScale);
      })
    ];
    gtk.font = {
      name = "sans-serif ${libGUI.size 10 { }}";
    };

    lib.gui = libGUI;
  } else {
    lib.gui = libGUI;
  };
}
