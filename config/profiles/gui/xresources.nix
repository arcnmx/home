{ config, pkgs, lib, ... }: let
  solarized = pkgs.fetchFromGitHub {
    owner = "solarized";
    repo = "xresources";
    rev = "025ceddbddf55f2eb4ab40b05889148aab9699fc";
    sha256 = "0lxv37gmh38y9d3l8nbnsm1mskcv10g3i83j0kac0a2qmypv1k9f";
  };
  solarizedPreprocessed = pkgs.runCommand "solarized" { inherit solarized; inherit (pkgs.stdenv) cc; } ''
    install -d $out
    declare -A backgrounds
    backgrounds[dark]=rgba:0000/22bb/3366/ee00
    backgrounds[light]=rgba:ffdd/ff66/ee33/ee88
    for style in light dark; do
      {
        $cc/bin/cpp -P -Dbackground=__disable < $solarized/Xresources.$style
        echo "*background: ''${backgrounds[$style]}"
      } > $out/Xresources.$style
    done
  '';
in {
  # TODO: set up https://github.com/sos4nt/dynamic-colors
  xresources = lib.mkIf config.home.profiles.gui {
    properties = {
      # Stolen from http://www.netswarm.net/misc/urxvt-xtermcompat.txt
      "*URxvt*keysym.Home" = ''\033OH'';
      "*URxvt*keysym.End" = ''\033OF'';
      "*URxvt*keysym.F1" = ''\033OP'';
      "*URxvt*keysym.F2" = ''\033OQ'';
      "*URxvt*keysym.F3" = ''\033OR'';
      "*URxvt*keysym.F4" = ''\033OS'';

      "URxvt.saveLines" = 16384;
      "URxvt.visualBell" = false;
      "URxvt.urgentOnBell" = true;
      "URxvt.imLocale" = "en_US.UTF-8";
      "URxvt.scrollBar" = false;
      "URxvt.cursorBlink" = false;
      "URxvt.iso14755" = false;
      "URxvt.fading" = 0;

      "URxvt.perl-ext-common" = "default,matcher,color-themes,osc-52,xresources-256";
      "URxvt.url-launcher" = "${config.programs.firefox.package}/bin/firefox";
      "URxvt.matcher.button" = 3;
      "URxvt.colorUL" = "#86a2be";
      "URxvt.keysym.M-f" = "perl:matcher:list";
      "URxvt.cutchars" = ''\\'"'&()*,;<=>?@[]^{|│└┼┴┬├─┤}·↪»'';

      "URxvt.color-themes.themedir" = config.xdg.configHome + "/urxvt/themes";
      "URxvt.color-themes.state-file" = config.xdg.dataHome + "/urxvt/theme";
      "URxvt.color-themes.autosave" = 1;
      "URxvt.color-themes.preprocessor" = "";
      "URxvt.keysym.C-grave" = "perl:color-themes:next";

      # Default Primary: mouse select to copy, Shift-Insert or Middle to paste
      # Default Clipboard: Ctrl+Alt+C to copy, Ctrl+Alt+V or Alt+Middle to paste
      "URxvt.keysym.S-M-Insert" = "eval:paste_clipboard"; # Shift-Alt-Insert paste
      "URxvt.keysym.S-M-C" = "eval:selection_to_clipboard"; # Shift-Alt-C copy
      "URxvt.keysym.S-M-V" = "eval:paste_clipboard"; # Shift-Alt-V paste

      #"URxvt*letterSpace" = -1;

      /*"Xft.dpi" = config.home.nixosConfig.fonts.fontconfig.dpi;
      "Xft.antialias" = config.home.nixosConfig.fonts.fontconfig.antialias;
      "Xft.rgba" = config.home.nixosConfig.fonts.fontconfig.subpixel.rgba;
      "Xft.hinting" = config.home.nixosConfig.fonts.fontconfig.hinting.enable;
      "Xft.hintstyle" = "hintfull";
      "Xft.autohint" = config.home.nixosConfig.fonts.fontconfig.hinting.autohint;
      "Xft.lcdfilter" = config.home.nixosConfig.fonts.fontconfig.subpixel.lcdfilter;*/
    } // (with lib; let
      normal = 710;
      bold = 711;
      italic = 712;
      ibold = 713;
      styles = {
        "${toString normal}" = ["medium"];
        "${toString bold}" = ["bold"];
        "${toString italic}" = ["italic"];
        "${toString ibold}" = ["italic" "bold"];
      };

      fontcommand = escape: font: ''\033]${toString escape};${concatStringsSep "," (toList font)}\007'';
      commands = fonts: "command:${concatStrings (toList fonts)}";

      fallbacks = ["Noto Mono" "Symbola"];
      monospace = "monospace";

      tamzenSize = {
        "9" = "9-65-100-100-c-50";
        "12" = "12-87-100-100-c-60";
        "13" = "13-101-100-100-c-70";
        "14" = "14-101-100-100-c-70";
        "15" = "15-108-100-100-c-80";
        "16" = "16-108-100-100-c-80";
        "20" = "20-145-100-100-c-100";
      };
      #tamzenName = "tamsyn";
      tamzenName = "tamzen";
      #tamzenName = "tamzenforpowerline";
      tamzen = size: style: let
        styleName = if style == normal then "medium" else "bold";
      in "-misc-${tamzenName}-${styleName}-r-normal--${tamzenSize.${toString size}}-iso8859-1";

      xft = name: options: let
        options' = if options == null then [] else (toList options);
        options'' = if length options' > 0 then ":${concatStringsSep ":" (toList options)}" else "";
      in "xft:${name}${options''}";

      fontsTamzen = size: style: let
        tamzenStyle = if style == normal || style == italic then normal else bold;
      in [(tamzen size tamzenStyle)] ++ (map (font: xft font ["pixelsize=${toString size}"]) fallbacks);
      fontsTtf = name: size: style:
        [(xft name (["size=${toString size}"] ++ styles.${toString style}))] ++
        (map (font: xft font ["size=${toString size}"]) fallbacks);

      fontcommands = fonts: size: map (style: fontcommand style (fonts size style)) [normal bold italic ibold];
      inherit (config.lib.gui) fontSize;
    in {
      "URxvt.font" = fontsTtf monospace (fontSize 9) normal;
      "URxvt.boldFont" = fontsTtf monospace (fontSize 9) bold;
      "URxvt.italicFont" = fontsTtf monospace (fontSize 9) italic;
      "URxvt.boldItalicFont" = fontsTtf monospace (fontSize 9) ibold;

      "URxvt.keysym.C-0" = commands (fontcommands (fontsTtf monospace) (fontSize 9));
      "URxvt.keysym.C-minus" = commands (fontcommands fontsTamzen 12);
      "URxvt.keysym.C-equal" = commands (fontcommands (fontsTtf monospace) (fontSize 12));
      #"URxvt*background" = "rgba:ffdd/ff66/ee33/ee88"; # light
      "URxvt*background" = "rgba:0000/22bb/3366/ee00"; # dark
    });
    #extraConfig = builtins.readFile "${solarized}/Xresources.light";
    extraConfig = builtins.readFile "${solarized}/Xresources.dark";
  };
  xdg.configFile."urxvt/themes/solarized_light".source = "${solarizedPreprocessed}/Xresources.light";
  xdg.configFile."urxvt/themes/solarized_dark".source = "${solarizedPreprocessed}/Xresources.dark";
  xdg.dataFile."urxvt/.keep".text = "";
}
