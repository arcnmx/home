{ config, pkgs, lib, ... }: with lib; let
  lxdm-session = pkgs.writeScript "lxdm-session.sh" ''
    #!${pkgs.bash}/bin/bash -l

    exec $HOME/.xinitrc
  '';
in
{
  options = {
    home.profiles.gui = mkEnableOption "graphical system";
  };

  config = mkIf config.home.profiles.gui {
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

      serverLayoutSection = ''
        Option "StandbyTime" "0"
        Option "SuspendTime" "0"
        Option "OffTime" "10"
      '';
      inputClassSections = [
        ''
          Identifier "Natural Scrolling"
          MatchIsPointer "on"
          Option "VertScrollDelta" "-1"
          Option "HorizScrollDelta" "-1"
          Option "DialDelta" "-1"
          Option "NaturalScrolling" "true"
        ''
        ''
          Identifier "screenstubignore"
          MatchDevicePath "/dev/input/event*"
          MatchUSBID "16c0:05df"
          Option "Ignore" "true"
        ''
        ''
          Identifier "nagatrinity"
          MatchIsPointer "on"
          MatchUSBID "1532:0067"
          Option "SampleRate" "1000"
          Option "Resolution" "5900"
          #Option "Sensitivity" "0.525"
        ''
        ''
          Identifier "naga2014"
          MatchIsPointer "on"
          MatchUSBID "1532:0040"
          Option "SampleRate" "1000"
          Option "Resolution" "3100"
          #Option "Sensitivity" "1.0"
        ''
      ];
      libinput.touchpad.naturalScrolling = true;
    };
    services.udev.extraRules = let
      openrazerDpi = pkgs.writeShellScript "openrazer-dpi" ''
        set -xeu

        printf %04x $1 | ${pkgs.xxd}/bin/xxd -r -p > /sys/$DEVPATH/dpi
      '';
    in ''
      ACTION=="change", DRIVER=="razermouse", ATTR{dpi}=="*", ATTRS{idVendor}=="1532", ATTRS{idProduct}=="0067", RUN+="${openrazerDpi} 5900"
      ACTION=="change", DRIVER=="razermouse", ATTR{dpi}=="*", ATTRS{idVendor}=="1532", ATTRS{idProduct}=="0040", RUN+="${openrazerDpi} 3100"
    '';
    hardware.openrazer = {
      devicesOffOnScreensaver = false;
      mouseBatteryNotifier = false;
      #syncEffectsEnabled = false;
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

    hardware.pulseaudio = {
      enable = true;
      daemon.config = {
        # pulse-daemon.conf(5)
        exit-idle-time = 5;
        #log-level = "debug";
        load-default-script-file = "yes";
        #default-script-file = "/etc/pulse/autoload.pa";
        resample-method = "speex-float-5";
        avoid-resampling = "true";
        flat-volumes = "no";
        #default-fragments = "4";
        #default-fragment-size-msec = "10";
        #default-sample-format = "s16le";
        #default-sample-rate = 44100;
        #alternate-sample-rate = 48000;
        #default-sample-channels = 2;
        #default-channel-map = "front-left,front-right";
        default-sample-format = "s32le";
        default-sample-rate = 48000;
        alternate-sample-rate = 44100;
        default-sample-channels = 2;
        #default-sample-channels = 2;
        #default-channel-map = "front-left,front-right";
      };
      clearDefaults = mkDefault true;
      x11bell.enable = mkDefault true;
      loadModule = mkMerge [
        (mkBefore [
          "device-restore"
          "stream-restore"
          "card-restore"

          "augment-properties"

          "switch-on-port-available"
        ])
        (mkAfter [
          "native-protocol-unix"
          {
            module = "native-protocol-tcp";
            opts.auth-ip-acl = "127.0.0.1;10.0.0.0/8";
          }
          "udev-detect"
          "default-device-restore"
          "always-sink"
          "intended-roles"
          "suspend-on-idle"
          "console-kit"
          "systemd-login"
          "position-event-sounds"
          "filter-heuristics"
          "filter-apply"

          /*{
            # Allow any user in X11 to access pulse
            # Using this also breaks pulse when SSH'ing with X11 forwarding enabled
            module = "x11-publish";
            opts.display = ":0";
          }*/

          "allow-passthrough"

          #"role-ducking" # ducks for as long as a matching stream exists, even if silent... unfortunately that makes it useless :<
        ])
      ];
      extraConfig = mkBefore ''
        .fail
      '';
    };
  };
}
