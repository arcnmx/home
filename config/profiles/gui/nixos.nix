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
      enableFontDir = true;
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
        Option "SuspendTime" "10"
        Option "OffTime" "20"
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
          Option "Sensitivity" "0.525"
        ''
        ''
          Identifier "naga2014"
          MatchIsPointer "on"
          MatchUSBID "1532:0040"
          Option "SampleRate" "1000"
          Option "Resolution" "3100"
          Option "Sensitivity" "1.0"
        ''
      ];
      libinput.naturalScrolling = true;
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

    hardware.pulseaudio.enable = true;
    hardware.pulseaudio.daemon.config = {
      # pulse-daemon.conf(5)
      exit-idle-time = 5;
      load-default-script-file = "yes";
      #default-script-file = "/etc/pulse/autoload.pa";
      resample-method = "src-sinc-best-quality";
      avoid-resampling = "true";
      flat-volumes = "no";
      default-sample-format = "s16le";
      default-sample-rate = 44100;
      alternate-sample-rate = 48000;
      default-sample-channels = 2;
      default-channel-map = "front-left,front-right";
    };
    hardware.pulseaudio.configFile = builtins.toFile "default.pa" "";
    hardware.pulseaudio.extraConfig = ''
      .fail

      load-module module-device-restore
      load-module module-stream-restore
      load-module module-card-restore

      load-module module-augment-properties

      load-module module-switch-on-port-available

      ### Load audio drivers statically if necessary
      #load-module module-alsa-sink
      #load-module module-alsa-source device=hw:1,0

      #load-module module-alsa-sink device=front:CARD=Generic,DEV=0
      #set-default-sink alsa_output.front_CARD_Generic_DEV_0

      load-module module-udev-detect

      #load-module module-bluetooth-policy
      #load-module module-bluetooth-discover

      load-module module-native-protocol-unix

      load-module module-native-protocol-tcp auth-ip-acl=127.0.0.1;10.0.0.0/8
      #load-module module-zeroconf-publish

      ### Load the RTP receiver module (also configured via paprefs)
      #load-module module-rtp-recv

      ### Load the RTP sender module (also configured via paprefs)
      #load-module module-null-sink sink_name=rtp format=s16be channels=2 rate=44100 sink_properties="device.description='RTP Multicast Sink'"
      #load-module module-rtp-send source=rtp.monitor

      #load-module module-gconf

      load-module module-default-device-restore

      load-module module-rescue-streams

      load-module module-always-sink

      load-module module-intended-roles

      load-module module-suspend-on-idle

      load-module module-console-kit
      load-module module-systemd-login

      load-module module-position-event-sounds

      #load-module module-role-cork

      load-module module-filter-heuristics
      load-module module-filter-apply

      load-sample x11-bell /usr/share/sounds/freedesktop/stereo/message.oga
      load-module module-x11-bell sample=x11-bell display=:0

      # Allow any user in X11 to access pulse
      # Using this also breaks pulse when SSH'ing with X11 forwarding enabled
      #load-module module-x11-publish display=:0

      load-module module-allow-passthrough

      load-module module-role-ducking

      # TODO: https://wiki.archlinux.org/index.php/PulseAudio/Troubleshooting#Enable_Echo.2FNoise-Cancellation
    '';
  };
}
