{ config, pkgs, lib, ... }: with lib; let
  lxdm-session = pkgs.writeScript "lxdm-session.sh" ''
    #!${pkgs.bash}/bin/bash -l

    exec $HOME/.xinitrc
  '';
  inherit (pkgs.arc.packages.personal) openrazer-dpi;
in
{
  imports = [
    ./dpms-standby.nix
  ];

  options = {
    hardware.display = {
      dpi = mkOption {
        type = types.float;
        default = 96.0;
      };
      dpiScale = mkOption {
        type = types.float;
        default = 1.0;
      };
      fontScale = mkOption {
        type = types.float;
        default = 1.0;
      };
    };
  };
  config = {
    home-manager.users.arc.imports = [ ./home.nix ];
    home.profileSettings.base.duc = pkgs.duc;

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

    services.pipewire = {
      enable = !config.hardware.pulseaudio.enable;
      alsa.enable = true;
      pulse.enable = true;
      jack.enable = true;
      config.pipewire = {
        "context.properties" = {
          "support.dbus" = true;
          "mem.allow-mlock" = true;
          "link.max-buffers" = 64;
          "default.clock.rate" = 48000;
          "default.clock.quantum" = 1024;
          "default.clock.min-quantum" = 32;
          "default.clock.max-quantum" = 8192;
          "default.video.rate.num" = 60;
          "log.level" = 3;
        };
        "context.objects" = [
          {
            factory = "spa-node-factory";
            args = {
              "factory.name" = "support.node.driver";
              "node.name" = "Dummy-Driver";
              "priority.driver" = 8000;
            };
          }
          /*{
            factory = "adapter";
            args = {
              "factory.name" = "api.alsa.pcm.source";
              "node.name" = "mic";
              "node.description" = "Mic";
              "media.class" = "Audio/Source";
              "api.alsa.path" = "hw:1,0";
              "audio.format" = "S16LE";
              "audio.rate" = 48000;
              "audio.channels" = 1;
            };
          }*/
        ];
        "context.modules" = [
          {
            name = "libpipewire-module-rtkit";
            args = {
              "nice.level" = -15;
              "rt.prio" = 88;
              "rt.time.soft" = 200000;
              "rt.time.hard" = 200000;
            };
            flags = [ "ifexists" "nofail" ];
          }
          { name = "libpipewire-module-protocol-native"; }
          { name = "libpipewire-module-profiler"; }
          { name = "libpipewire-module-metadata"; }
          { name = "libpipewire-module-spa-device-factory"; }
          { name = "libpipewire-module-spa-node-factory"; }
          { name = "libpipewire-module-client-node"; }
          { name = "libpipewire-module-client-device"; }
          {
            name = "libpipewire-module-portal";
            flags = [ "ifexists" "nofail" ];
          }
          {
            name = "libpipewire-module-access";
            args = {};
          }
          { name = "libpipewire-module-adapter"; }
          { name = "libpipewire-module-link-factory"; }
          { name = "libpipewire-module-session-manager"; }
        ];
      };
      config.pipewire-pulse = {
        "context.modules" = [
          {
            name = "libpipewire-module-rtkit";
            args = {
              "nice.level" = -15;
              "rt.prio" = 88;
              "rt.time.soft" = 200000;
              "rt.time.hard" = 200000;
            };
            flags = [ "ifexists" "nofail" ];
          }
          { name = "libpipewire-module-protocol-native"; }
          { name = "libpipewire-module-client-node"; }
          { name = "libpipewire-module-adapter"; }
          { name = "libpipewire-module-metadata"; }
          {
            name = "libpipewire-module-protocol-pulse";
            args = {
              "pulse.min.req" = "32/48000";
              "pulse.default.req" = "1024/48000";
              "pulse.max.req" = "8192/48000";
              "pulse.min.quantum" = "32/48000";
              "pulse.max.quantum" = "8192/48000";
              "server.address" = [ "unix:native" ];
            };
          }
        ];
        #"stream.properties" = {
        #  "node.latency" = "32/48000";
        #  "resample.quality" = 1;
        #};
      };
      media-session = {
        config = {
          media-session = {
            "context.properties" = {
              "log.level" = 3;
            };
          };
          alsa-monitor = {
            rules = [
              {
                matches = [ { "node.name" = "alsa_output.*"; } ];
                actions = {
                  update-props = {
                    "audio.format" = "S32LE";
                    "audio.allowed-rates" = "48000,96000";
                    #"api.alsa.period-size" = 32; # defaults to 1024, tweak by trial-and-error
                    "node.pause-on-idle" = true;
                    #"api.alsa.disable-batch" = true; # generally, USB soundcards use the batch mode
                    "session.suspend-timeout-seconds" = 30; # 0 disables suspend
                  };
                };
              }
            ];
          };
          bluez-monitor = {
            #properties = {
            #  bluez5.codecs = [ "sbc" ];
            #};
            rules = [
              {
                matches = [ { "device.name" = "~bluez_card.*"; } ];
                actions = {
                  update-props = {
                    "bluez5.reconnect-profiles" = [ "hfp_hf" "hsp_hs" "a2dp_sink" ];
                    "bluez5.msbc-support" = true;
                  };
                };
              }
              {
                matches = [
                  { "node.name" = "~bluez_input.*"; }
                  { "node.name" = "~bluez_output.*"; }
                ];
                actions = {
                  "node.pause-on-idle" = false;
                };
              }
            ];
          };
        };
      };
    };
    services.wireplumber.alsa.migrateMediaSession = mkDefault true;
    hardware.pulseaudio = {
      enable = false;
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
    hardware.alsa.enable = true;
  };
}
