{ config, lib, ... }: with lib; {
  imports = [
    ./pipewire.nix
  ];
  config = {
    services.pipewire = {
      enable = !config.hardware.pulseaudio.enable;
      alsa.enable = true;
      pulse.enable = true;
      jack.enable = true;
      confSettings.pipewire = {
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
        #"context.objects".Dummy-Driver.args."priority.driver" = 8000;
        /*"context.objects".mic = {
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
        "context.modules" = mkBefore [
          {
            name = "libpipewire-module-rt";
            args = {
              "nice.level" = -15;
              "rt.prio" = 90;
              "rt.time.soft" = 200000;
              "rt.time.hard" = 200000;
            };
            flags = [ "ifexists" "nofail" ];
          }
        ];
      };
      confSettings.pipewire-pulse = {
        "pulse.properties" = {
          "pulse.min.req" = "32/48000";
          "pulse.default.req" = "1024/48000";
          "pulse.max.req" = "8192/48000";
          "pulse.min.quantum" = "32/48000";
          "pulse.max.quantum" = "8192/48000";
          "server.address" = [ "unix:native" ];
        };
        "context.modules" = mkBefore [
          {
            name = "libpipewire-module-rt";
            args = {
              "nice.level" = -11;
              "rt.prio" = 88;
              "rt.time.soft" = 200000;
              "rt.time.hard" = 200000;
            };
            flags = [ "nofail" ];
          }
        ];
        #"stream.properties" = {
        #  "node.latency" = "32/48000";
        #  "resample.quality" = 1;
        #};
      };
    };
    services.wireplumber = {
      enable = mkDefault config.services.pipewire.enable;
      alsa.rules.output = {
        matches = singleton {
          verb = "matches";
          subject = "node.name";
          comparison = "alsa_output.*";
        };
        apply = {
          "audio.format" = "S32LE";
          "audio.allowed-rates" = "48000,96000";
          #"api.alsa.period-size" = 32; # defaults to 1024, tweak by trial-and-error
          "node.pause-on-idle" = true;
          #"api.alsa.disable-batch" = true; # generally, USB soundcards use the batch mode
          "session.suspend-timeout-seconds" = 30; # 0 disables suspend
        };
      };
      /*bluez.rules = { # TODO
        device = {
          matches = singleton {
            verb = "matches";
            subject = "device.name";
            comparison = "~bluez_card.*";
          };
          apply = {
            "bluez5.reconnect-profiles" = [ "hfp_hf" "hsp_hs" "a2dp_sink" ];
            "bluez5.msbc-support" = true;
          };
        };
        idle = {
          matches = map (comparison: {
            verb = "matches";
            subject = "node.name";
          }) [ "~bluez_input.*" "~bluez_output.*" ];
          apply = {
            "node.pause-on-idle" = false;
          };
        };
      };*/
    };
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
