{ pkgs, config, lib, ... }: with lib; let
  pwName = desc: replaceStrings [ " " ] [ "_" ] (toLower desc);
  pwList = concatStringsSep ",";
  wpLinkModule = "libwpscripts_static_link";
  pwLink = {
    output
  , input
  , mappings
  , linkvolume ? "output"
  }: {
    output = singleton [ "node.name" "=" output ];
    input = singleton [ "node.name" "=" input ];
    link_volume = linkvolume;
    mappings = mapAttrsToList (key: value: {
      output = singleton [ "audio.channel" "=" key ];
      input = singleton [ "audio.channel" "=" value ];
    }) mappings;
  };
  channelMapDefaults = {
    "1" = singleton "MONO";
    "2" = [ "FL" "FR" ];
    "6" = [ "FL" "FR" "RL" "RR" "SL" "SR" ];
  };
  pwNode = {
    name ? pwName desc
  , nick ? name
  , desc
  , channels ? 2
  , channelMap ? channelMapDefaults.${toString channels}
  , pauseOnIdle ? true
  , prio ? 1000
  , monitorVolume ? false
  }: {
    "node.name" = name;
    "node.nick" = nick;
    "node.description" = desc;
    "audio.channels" = channels;
    "audio.position" = pwList channelMap;
    "node.pause-on-idle" = pauseOnIdle;
    "monitor.channel-volumes" = monitorVolume;
    "priority.session" = prio;
  };
  pwVirtual = {
    sink ? true
  , channels ? if sink then 2 else 1
  , ...
  }@args: {
    factory = "adapter";
    args = pwNode (removeAttrs args [ "sink" ] // { inherit channels; }) // {
      "factory.name" = "support.null-audio-sink";
      "media.class" = if sink then "Audio/Sink" else "Audio/Source/Virtual";
    };
  };
  aecArgs = {
    default = {
      # https://wiki.archlinux.org/title/PulseAudio#Possible_'aec_args'_for_'aec_method=webrtc'
      analog_gain_control = false;
      digital_gain_control = true;
      noise_suppression = true;
      high_pass_filter = false;
      voice_detection = true;
      extended_filter = true;
      experimental_agc = true;
      #intelligibility_enhancer = false;
      intelligibility_enhancer = true;
    };
    rnnoiseBase = {
      # features that rnnoise does better
      noise_suppression = false;
      extended_filter = false;
      #voice_detection = false;
      #experimental_agc = false;
    };
    rnnoise = aecArgs.default // aecArgs.rnnoiseBase // {
      digital_gain_control = false;
    };
  };
  formatAecValue = v:
    if v == true then "1"
    else if v == false then "0"
    else toString v;
  formatAecArgs = args: concatStringsSep " " (mapAttrsToList (k: v: "${k}=${formatAecValue v}") args);
  pwEchoCancelModule = "libpipewire-module-echo-cancel";
  pwEchoCancel = {
    method ? "webrtc"
  , args ? aecArgs.default
  , capture ? { }
  , playback ? { }
  }: {
    #"audio.channels" = 1;
    #"audio.position" = pwList [ "MONO" ];
    "aec.method" = method;
    "aec.args" = formatAecArgs args;
  } // optionalAttrs (capture != { }) {
    "sink.props" = toString capture;
  } // optionalAttrs (playback != { }) {
    "source.props" = toString playback;
  };
  rnnoise = {
    name ? "rnnoise"
  , nnoiseless ? false
  , threshold ? 50.0
  }: {
    inherit name;
    type = "ladspa";
    # TODO: latency = "480/48000";
  } // optionalAttrs (!nnoiseless) {
    plugin = "${pkgs.rnnoise-plugin-develop}/lib/ladspa/librnnoise_ladspa${pkgs.hostPlatform.extensions.sharedLibrary}";
    label = "noise_suppressor_stereo";
    control = {
      "VAD Threshold (%)" = threshold;
    };
  } // optionalAttrs nnoiseless {
    plugin = "${pkgs.ladspa-rnnoise}/lib/ladspa/libladspa_rnnoise_rs${pkgs.hostPlatform.extensions.sharedLibrary}";
    label = "mono_nnnoiseless";
  };
  pwFilterNode = {
    type ? "ladspa" # ladspa, builtin
  , name ? label
  , label
  , plugin ? null
  , control ? { }
  }: {
    inherit type name label;
  } // optionalAttrs (plugin != null) {
    inherit plugin;
  };
  pwFilterModule = "libpipewire-module-filter-chain";
  pwFilter = {
    name ? pwName desc
  , nick ? name
  , desc
  , nodes
  , nodeLinks ? { }
  , inputs ? [ ]
  , outputs ? [ ]
  , capture ? { }
  , playback ? { }
  }: {
    "node.name" = name;
    "node.description" = desc;
    "media.name" = desc;
    "filter.graph" = {
      nodes = map pwFilterNode nodes;
    } // optionalAttrs (nodeLinks != { }) {
      links = mapAttrsToList (input: output: {
        inherit input output;
      }) nodeLinks;
    } // optionalAttrs (inputs != [ ] || outputs != [ ]) {
      inherit inputs outputs;
      #inputs = [ "rnnoise:In" ];
      #outputs = [ "rnnoise:Out" ];
    };
    "capture.props" = {
      "node.passive" = true;
      #"media.class" = "Audio/Sink";
    } // optionalAttrs (inputs != [ ]) {
      "audio.channels" = length inputs;
      "audio.position" = pwList channelMapDefaults.${toString (length inputs)};
    } // capture;
    "playback.props" = {
      "node.passive" = true;
      #"media.class" = "Audio/Source";
    } // optionalAttrs (outputs != [ ]) {
      "audio.channels" = length outputs;
      "audio.position" = pwList channelMapDefaults.${toString (length outputs)};
    } // playback;
  };
in {
  config = mkIf config.home.profiles.host.shanghai {
    services.wireplumber = {
      enable = true;
      alsa = {
        rules = {
          hdmi-lowprio = {
            matches = {
              subject = "api.alsa.path";
              comparison = "hdmi:.*";
              #"alsa.card_name" = "HDA NVidia";
            };
            apply = {
              "priority.session" = 100;
              "node.pause-on-idle" = true;
            };
          };
          onboard-card = {
            matches = singleton [
              { subject = "media.class"; comparison = "Audio/Device"; }
              { subject = "device.product.name"; comparison = "Starship/Matisse HD Audio Controller"; }
              #"api.alsa.card.mixername" = "Realtek ALC1220";
              #"device.name" = "~alsa_card.*";
              #"device.vendor.id" = 4130;
              #"device.product.id" = 5255;
            ];
          };
          onboard-analog = {
            matches = singleton [
              { subject = "alsa.id"; comparison = "ALC1220 Analog"; }
              { subject = "api.alsa.pcm.stream"; comparison = "playback"; }
            ];
            apply = pwNode {
              name = "onboard";
              desc = "Onboard Audio";
              channels = 6;
              prio = 50;
            } // {
              "session.suspend-timeout-seconds" = 60;
              "api.alsa.period-size" = 512;
            };
          };
          onboard-optical = {
            matches = singleton [
              { subject = "alsa.id"; comparison = "ALC1220 Digital"; }
              { subject = "api.alsa.pcm.stream"; comparison = "playback"; }
            ];
            apply = pwNode {
              name = "headphones";
              desc = "Headphones (Optical)";
              prio = 1000;
            } // {
              "session.suspend-timeout-seconds" = 30;
              "api.alsa.period-size" = 512;
              "audio.format" = "S32LE";
              "resample.quality" = 6;
            };
          };
          onboard-mic = {
            matches = singleton [
              { subject = "alsa.id"; comparison = "ALC1220 Analog"; }
              { subject = "api.alsa.pcm.stream"; comparison = "capture"; }
            ];
            apply = pwNode {
              desc = "Onboard Mic";
              prio = 100;
            } // {
              "session.suspend-timeout-seconds" = 60;
            };
          };
          onboard-mic-broken = { # TODO: this doesn't appear anymore?
            matches = singleton [
              { subject = "alsa.id"; comparison = "ALC1220 Alt Analog"; }
              { subject = "api.alsa.pcm.stream"; comparison = "capture"; }
            ];
            apply = pwNode {
              name = "onboard_mic_alt";
              desc = "Alt Onboard Mic";
              prio = 25;
            } // {
              "node.disabled" = true;
            };
          };
          e22 = {
            matches = singleton [
              { subject = "alsa.id"; comparison = "USB Audio"; }
              { subject = "api.alsa.pcm.stream"; comparison = "capture"; }
              { subject = "alsa.card_name"; comparison = "HD  microphone"; }
            ];
            apply = pwNode {
              name = "mic_e22";
              desc = "Mic (E22 USB)";
              channels = 2; # only one mic is connected but...
              prio = 30;
            } // {
              "session.suspend-timeout-seconds" = 60;
              #"api.alsa.period-size" = 512;
            };
          };
        };
      };
      components = singleton {
        name = wpLinkModule;
        type = "module";
        arguments = map pwLink [
          { output = "headset"; input = "onboard"; mappings = {
            "FL" = "FL";
            "FR" = "FR";
          }; }
          { output = "speakers"; input = "onboard"; mappings = {
            "FL" = "RL";
            "FR" = "RR";
          }; }
          { output = "amp"; input = "onboard"; mappings = {
            "FL" = "SL";
            "FR" = "SR";
          }; }
          #"onboard_mic:capture_FL" = "mic:input_MONO";
          { output = "mic_e22"; input = "mic"; mappings = {
            "FL" = "MONO";
          }; linkvolume = "input"; }
          { output = "stream"; input = "stream_live"; mappings = {
            "FL" = "FL";
            "FR" = "FR";
          }; linkvolume = null; }
          { output = "stream"; input = "stream_vod"; mappings = {
            "FL" = "FL";
            "FR" = "FR";
          }; linkvolume = null; }
        ];
      } ++ [
        /*{ name = pwFilterModule;
          type = "pw_module";
          arguments = pwFilter {
            desc = "RNNoise";
            nodes = singleton (pwFilterNode (rnnoise { nnoiseless = false; }));
          };
        }*/
        /*{ name = pwEchoCancelModule;
          type = "pw_module";
          arguments = pwEchoCancel { args = aecArgs.rnnoise; };
        }*/
      ];
    };
    services.pipewire = {
      config.pipewire = {
        "context.objects" = map pwVirtual [
          { desc = "Headset"; prio = 1500; }
          { desc = "Speakers"; prio = 1000; }
          { desc = "Amp"; prio = 100; }
          { desc = "Mic"; sink = false; prio = 1000; monitorVolume = true; }
          { name = "stream_live"; desc = "Stream Audio (Live)"; monitorVolume = true; prio = 0; }
          { name = "stream_vod"; desc = "Stream Audio (VOD)"; monitorVolume = true; prio = 0; }
          { name = "stream"; desc = "Stream Audio"; monitorVolume = true; prio = 0; }
        ];
      };
    };
    hardware.alsa = {
      ucm = {
        enable = true;
        cards = {
          onboard = {
            cardDriver = "snd_hda_intel";
            cardName = "HD-Audio Generic";
            comment = "Onboard Audio";

            useCases = {
              multichannel = {
                name = "HiFi";
                comment = "Multichannel Onboard";
                devices = [ "analog" "digital" "mic" ];
                set = {
                  "Master Playback Volume" = 87;
                  "Auto-Mute Mode" = false;
                  "Loopback Mixing" = false;
                  "Input Source,0" = 2; # front, rear, line
                  #"Rear Mic Boost Volume" = 0; # headset
                  #"Line Boost Volume" = 2; # condenser
                  "Capture Switch,1" = false; # this driver is broken, don't use it?
                };
                modifiers = {
                  mic = {
                    supportedDevice = [ "mic" ];
                    set = {
                      "Input Source,0" = 1; # front, rear, line
                      "Rear Mic Boost Volume" = 0;
                    };
                  };
                  condenser = {
                    supportedDevice = [ "mic" ];
                    set = {
                      "Input Source,0" = 2; # front, rear, line
                      "Line Boost Volume" = 2;
                    };
                  };
                };
              };
            };
            devices = {
              analog = {
                name = "Onboard";
                comment = "Multichannel";
                playback = {
                  pcm = "hw:\${CardId}";
                  mixer = "Multichannel";
                  master = "Master";
                  channels = 6;
                  ctl = "remap";
                };
                ctl = "hw:\${CardId}";

                toneQuality = "Music"; # Voice?
              };
              digital = {
                name = "SPDIF";
                comment = "S/PDIF";
                playback = rec {
                  ctl = "hw:\${CardId}";
                  pcm = "${ctl},1";
                  mixer = "IEC958 Default PCM";
                  channels = 2;
                };
                toneQuality = "Music";
                set = {
                  "IEC958 Playback Switch" = true;
                };
              };
              mic = {
                name = "Mic";
                comment = "Mic";
                capture = {
                  pcm = "hw:\${CardId}";
                  mixer = "Capture,0";
                  channels = 2;
                };
                toneQuality = "Voice";
              };
              mic-alt = {
                name = "Line-In";
                comment = "Mic (Alt)";
                capture = {
                  pcm = "hw:\${CardId},2";
                  mixer = "Capture,1";
                  channels = 2;
                };
                toneQuality = "Voice";
                conflictingDevice = [ "mic" ];
              };
            };
          };
          /*usb-headset = {
            cardDriver = "snd-usb-audio";
            cardName = "USB Audio Device";
            comment = "USB Audio (Headset)";

            useCases = {
              headset-usb = {
                name = "Headset";
                comment = "Headset (USB)";
                devices = [ "headset-usb" ];
              };
            };
            devices = {
              headset-usb = {
                name = "USB";
                comment = "USB Headset";
                set = {
                  "Mic Capture Volume" = 30;
                };
                capture = {
                  pcm = "hw:\${CardId}";
                  mixer = "Mic";
                  channels = 1;
                };
                playback = {
                  pcm = "hw:\${CardId}";
                  mixer = "Speaker";
                  channels = 2;
                };
                toneQuality = "Voice";
              };
            };
          };*/
          e22 = {
            cardDriver = "snd-usb-audio";
            cardName = "HD  microphone"; # 2 spaces yes
            comment = "Mic (E22 USB)";

            useCases = {
              e22 = {
                name = "E22";
                comment = "Mic (E22 USB)";
                devices = [ "e22" ];
              };
            };
            devices.e22 = {
              name = "E22";
              comment = "USB Mic";
              #set = {
              #  "Mic Capture Volume" = 67;
              #};
              capture = {
                pcm = "hw:\${CardId}";
                mixer = "Mic";
                channels = 2;
              };
              toneQuality = "Voice";
            };
          };
        };
      };
      config = let
        inherit (config.hardware.alsa.ucm.cards.onboard.devices.analog) playback;
      in {
        ctl.${playback.ctl} = {
          type = "remap";
          child = {
            type = "hw";
            card = "Generic";
          };
          map."name='${playback.mixer} Volume'" = {
            "name='Headphone+LO Playback Volume'" = {
              vindex."0" = 0;
              vindex."1" = 1;
            };
            "name='Surround Playback Volume'" = {
              vindex."2" = 0;
              vindex."3" = 1;
            };
            "name='Center Playback Volume'" = {
              vindex."4" = 0;
            };
            "name='LFE Playback Volume'" = {
              vindex."5" = 0;
            };
          };
          map."name='${playback.mixer} Switch'" = {
            "name='Front Playback Switch'" = {
              vindex."0" = 0;
              vindex."1" = 1;
            };
            "name='Surround Playback Switch'" = {
              vindex."2" = 0;
              vindex."3" = 1;
            };
            "name='Center Playback Switch'" = {
              vindex."4" = 0;
            };
            "name='LFE Playback Switch'" = {
              vindex."5" = 0;
            };
          };
        };
      };
    };
  };
}
