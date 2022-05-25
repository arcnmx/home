{ lib, ... }: with lib; {
  config = {
    hardware.pulseaudio = {
      loadModule = [
        # "mmkbd-evdev"
        {
          module = "alsa-sink";
          opts = {
            sink_name = "onboard";
            device = "front:CARD=PCH,DEV=0";
            format = "s32";
            rate = 48000;
            channels = 2;
            tsched = true;
            fixed_latency_range = false;
          };
        }
        {
          module = "alsa-source";
          opts = {
            source_name = "mic";
            device = "front:CARD=PCH,DEV=0";
            format = "s32";
            rate = 48000;
            tsched = true;
          };
        }
        {
          module = "echo-cancel";
          opts = {
            source_master = "mic";
            sink_master = "onboard";
            source_name = "mic_echo";
            sink_name = "mic_echo_sink";
            use_volume_sharing = true;
            use_master_format = true;
            channels = 1;
            aec_method = "webrtc";
            aec_args = {
              # https://wiki.archlinux.org/index.php/PulseAudio/Troubleshooting#Enable_Echo.2FNoise-Cancellation
              agc_start_volume = 150;
              analog_gain_control = false;
              digital_gain_control = true;
              noise_suppression = true;
              high_pass_filter = false; # true?
              extended_filter = true;
              experimental_agc = true;
              intelligibility_enhancer = false;
            };
          };
        }
      ];
      defaults = {
        source = "mic";
        sink = "onboard";
      };
    };
  };
}
