{ config, pkgs, lib, ... }: with lib; let
  lxdm-session = pkgs.writeScript "lxdm-session.sh" ''
    #!${pkgs.bash}/bin/bash -l

    exec $HOME/.xinitrc
  '';
  inherit (pkgs.arc.packages.personal) openrazer-dpi;
  inherit (config.services) xserver;
in
{
  imports = [
    ./dpms-standby.nix
    ./idle.nix
    ./dpi.nix
    ./audio.nix
  ];

  options = {
    hardware.display = {
      oled = mkOption {
        type = types.listOf types.str;
        default = [ ];
      };
      dpms = {
        screensaverSeconds = mkOption {
          type = types.int;
          default = config.hardware.display.dpms.screensaverMinutes * 60;
        };
        screensaverCycleSeconds = mkOption {
          type = types.int;
          default = 600;
        };
      };
    };
    services.xserver = {
      staticDisplay = mkOption {
        type = types.nullOr types.int;
        default = xserver.display;
      };
      authority = mkOption {
        type = types.nullOr types.path;
        default = null;
      };
    };
  };
  config = {
    home-manager.users.arc.imports = [ ./home.nix ];
    home.profileSettings.base.duc = pkgs.duc;
    users.users.arc.systemd.translate.units = [ "graphical-session.target" ];
    security.polkit.users."" = mkIf config.services.dpms-standby.enable {
      systemd.units = singleton "dpms-standby.service";
    };
    services.systemd2mqtt.units = {
      ${toString config.users.users.arc.systemd.translate.units."graphical-session.target".systemTarget.name} = {
        settings.readonly = true;
      };
      "dpms-standby.service" = mkIf config.services.dpms-standby.enable {
        settings.invert = true;
      };
    };

    # TODO: alsa fallback to pulse mixer (see shanghai /etc/asound.conf)

    xdg.portal = {
      enable = false; # true?
      #gtkUsePortal = true;
      #extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    };

    fonts = {
      enableDefaultFonts = true;
      fontDir.enable = true;
      fontconfig = {
        enable = true;
        defaultFonts.monospace = ["Hack" "DejaVu Sans Mono"];
      };
      fonts = [
        pkgs.noto-fonts
        pkgs.noto-fonts-emoji
        #pkgs.noto-fonts-extra
        #pkgs.droid-sans-mono-dotted
        pkgs.symbola
        pkgs.tamzen
        pkgs.tamsyn
        pkgs.hack-font
        # pkgs.iosevka # fancy monospace font?
      ];
    };
    services.xserver = {
      enable = true;
      exportConfiguration = true;
      displayManager.startx.enable = true;
      staticDisplay = mkIf xserver.displayManager.lightdm.enable (mkDefault 0);
      authority = mkIf (xserver.staticDisplay != null && xserver.displayManager.lightdm.enable) (mkDefault
        "/var/run/lightdm/root/:${toString xserver.staticDisplay}"
      );

      inputClassSections = [
        ''
          Identifier "adcignore"
          MatchDevicePath "/dev/input/event*"
          MatchUSBID "f213:1a0a"
          Option "Ignore" "true"
        '' # this "HD  microphone" thing spams media keys
        ''
          Identifier "screenstubignore"
          MatchDevicePath "/dev/input/event*"
          MatchUSBID "16c0:05df"
          Option "Ignore" "true"
        ''
        ''
          Identifier "Natural Scrolling"
          MatchIsPointer "on"
          Option "VertScrollDelta" "-1"
          Option "HorizScrollDelta" "-1"
          Option "DialDelta" "-1"
          Option "NaturalScrolling" "true"
        ''
        ''
          Identifier "nagatrinity"
          MatchIsPointer "on"
          MatchUSBID "1532:0067"
          Option "SampleRate" "1000"
          Option "Resolution" "5900"
        ''
        ''
          Identifier "naga2014"
          MatchIsPointer "on"
          MatchUSBID "1532:0040"
          Option "SampleRate" "1000"
          Option "Resolution" "3100"
        ''
      ];
      libinput.touchpad.naturalScrolling = true;
    };
    hardware.display.dpms = mkIf config.services.idle.enable {
      screensaverMinutes = mkDefault (
        config.hardware.display.dpms.standbyMinutes + 1
      );
      screensaverCycleSeconds = mkDefault 0;
    };

    systemd.services.display-manager = {
      bindsTo = [ "graphical.target" ];
      serviceConfig.OOMScoreAdjust = -500;
    };
    services.udev.extraRules = ''
      ACTION=="change", DRIVER=="razermouse", ATTR{dpi}=="*", ATTRS{idVendor}=="1532", ATTRS{idProduct}=="0067", RUN+="${openrazer-dpi} 5900"
      ACTION=="change", DRIVER=="razermouse", ATTR{dpi}=="*", ATTRS{idVendor}=="1532", ATTRS{idProduct}=="0040", RUN+="${openrazer-dpi} 3100"
    '';
    hardware.openrazer = {
      devicesOffOnScreensaver = false;
      mouseBatteryNotifier = false;
      #syncEffectsEnabled = false;
      users = [ "arc" ];
    };

    # TODO: gui/usr/lib/firefox overrides

    environment.etc = lib.mkIf false {
      "lxdm/LoginReady" = {
        text = ''
          #!${pkgs.bash}/bin/sh

          XAUTHORITY="/run/lxdm/lxdm-$DISPLAY.auth" ${pkgs.arc.konawall.exec} &
        '';
        mode = "0755";
      };
      "lxdm/lxdm.conf".text = ''
        [base]
        session=${lxdm-session}
        greeter=${pkgs.lxdm}/lib/lxdm/lxdm-greeter-gtk

        [server]
        arg=${pkgs.xorg.xorgserver}/bin/X -background vt1

        [display]
        gtk_theme=Adwaita
        # bg=/usr/share/backgrounds/default.png
        bottom_pane=0
        lang=0
        keyboard=0
        theme=Industrial

        [input]

        [userlist]
        disable=1
        white=
        black=
      '';
    };
    environment.systemPackages = [ openrazer-dpi ];
  };
}
