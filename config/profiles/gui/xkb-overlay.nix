self: super: {
  xorg = super.xorg // {
    xorgserver = super.xorg.xorgserver.overrideAttrs (old: {
      configureFlags = old.configureFlags ++ [
        "--with-xkb-bin-directory=${self.xorg.xkbcomp}/bin"
        "--with-xkb-path=${self.xkeyboard-config-arc}/share/X11/xkb"
      ];
    });

    setxkbmap = super.xorg.setxkbmap.overrideAttrs (old: {
      postInstall = ''
        mkdir -p $out/share
        ln -sfn ${self.xkeyboard-config-arc}/etc/X11 $out/share/X11
      '';
    });

    xkbcomp = super.xorg.xkbcomp.overrideAttrs (old: {
      configureFlags = [ "--with-xkb-config-root=${self.xkeyboard-config-arc}/share/X11/xkb" ];
    });
  };
}
