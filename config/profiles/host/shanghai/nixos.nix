{ tf, config, pkgs, lib, ... }: with lib; {
  imports = [
    ./audio.nix
  ];

  options = {
    home.profiles.host.shanghai = mkEnableOption "hostname: shanghai";
  };

  config = mkIf config.home.profiles.host.shanghai {
    home.profiles.trusted = true;
    home.profiles.host.gensokyo = true;
    home.profiles.personal = true;
    home.profiles.gui = true;
    home.profiles.vfio = true;
    home.profiles.hw.nvidia = true;
    home.profiles.hw.x570am = true;
    home.profiles.hw.cross = true;

    networking = {
      hostId = "a1184652";
      useDHCP = false;
      useNetworkd = true;
      nftables.ruleset = mkAfter (builtins.readFile ./files/nftables.conf);
    };
    deploy.network.local.ipv4 = "10.1.1.32";
    systemd.network.networks.br = {
      matchConfig.Name = "br";
      gateway = [ "10.1.1.1" ];
      address = [ "${config.deploy.network.local.ipv4}/24" ];
    };
    deploy.tf = {
      dns.records = mkIf (config.home.profileSettings.gensokyo.zone != null) {
        hourai = {
          inherit (tf.dns.records.local_a) zone;
          domain = "hourai";
          a.address = "10.1.1.36";
        };
      };
    };

    home.nixbld.enable = true;
    services.ddclient.enable = true;
    services.mosh = {
      enable = true;
      ports = {
        from = 32600;
        to = 32700;
      };
    };
    services.ofono.enable = true;
    systemd.services.ofono.wantedBy = [ "multi-user.target" ];
    services.openssh.ports = [ 22 32022 ];
    hardware.openrazer.enable = true;
    hardware.pulseaudio = let
      default_aec_args = {
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
      rnnoise_aec_args = {
        # features that rnnoise does better
        noise_suppression = false;
        extended_filter = false;
        #voice_detection = false;
        #experimental_agc = false;
      };
      channel_map_list =
        [ "front-left" "front-right" "rear-left" "rear-right" "side-left" "side-right" ];
      toChannelMap = channels: let
      in optionals (channels > 1) (sublist 0 2 channel_map_list)
        ++ optionals (channels > 3) (sublist 2 2 channel_map_list)
        ++ optionals (channels > 5) (sublist 4 2 channel_map_list)
        ++ optional (mod channels 2 == 1) (if channels == 1 then "mono" else "lfe");
      channelConfig = channels: {
        "2" = "front";
        "3" = "surround21";
        "4" = "surround40";
        #"5" = "surround41";
        #"5" = "surround50"; # ambiguous
        "6" = "surround51";
        "8" = "surround71";
      }.${toString channels} or (throw "unsupported");
      ladspa-sink = { name, description ? name, rate ? 48000, channels ? length sources, outChannels ? 1, opts ? { }, sources ? [ source ], source ? null }: [
        {
          module = "null-sink";
          opts = {
            sink_name = "${name}_outsink";
            inherit rate;
            channels = outChannels;
            channel_map = toChannelMap outChannels;
            sink_properties = {
              "device.description" = "${description} Output";
            };
          };
        }
        {
          module = "ladspa-sink";
          opts = {
            sink_name = "${name}_sink";
            sink_master = "${name}_outsink";
            format = "float32";
            inherit rate channels;
            channel_map = toChannelMap channels;
            sink_properties = {
              "device.description" = "LADSPA ${description} Sink";
            };
          } // opts;
        }
        { # alias the monitor
          module = "remap-source";
          opts = {
            source_name = name;
            master = "${name}_outsink.monitor";
            source_properties = {
              "device.description" = description;
            };
          };
        }
      ] ++ concatLists (imap0 (i: source: let
        sourceId = source.opts.source_name or source;
        sourceName = "source${toString i}";
        channel = elemAt (toChannelMap channels) i;
        description = "LADSPA ${name} ${sourceName}";
        sink_input_properties = {
          "media.name" = "${description} Input";
        };
        source_output_properties = {
          "media.name" = "${description} Output";
        };
        loopback = {
          module = "loopback";
          opts = {
            source = if hasRemap then remap.opts.source_name else "${sourceId}";
            sink = "${name}_sink";
            source_dont_move = true;
            sink_dont_move = true;
            remix = false;
            inherit sink_input_properties source_output_properties;
          };
        };
        hasRemap = length sources > 1;
        remap = {
          module = "remap-source";
          opts = {
            source_name = "${name}_${sourceName}";
            master = "${sourceId}";
            channels = 1;
            channel_map = [ channel ];
            master_channel_map = toChannelMap (source.opts.channels or 1);
            remix = false;
            source_properties = {
              "device.description" = description;
            };
          };
        };
      in optional (isAttrs source) source ++ optional hasRemap remap ++ singleton loopback) sources);
      usb = "usb-C-Media_Electronics_Inc._USB_Audio_Device-00";
      channels = 6; # NOTE: first two channels include an amp for headphones, 3rd needs an external amp
    in {
      loadModule = mkMerge [ [
        # "mmkbd-evdev"
        {
          module = "alsa-sink";
          opts = {
            sink_name = "onboard";
            device = "${channelConfig channels}:CARD=Generic,DEV=0";
            format = "s32";
            rate = 48000;
            inherit channels;
            channel_map = toChannelMap channels;
            tsched = true;
            fixed_latency_range = false;
            fragment_size = 1024;
            fragments = 16;
          };
        }
        {
          module = "remap-sink";
          opts = {
            sink_name = "speakers";
            master = "onboard";
            channels = 2;
            channel_map = toChannelMap 2;
            master_channel_map = sublist 2 2 (toChannelMap channels);
            remix = false;
            sink_properties = {
              "device.description" = "Speakers";
            };
            # source_properties = "device.description=Speakers2";
          };
        }
        {
          module = "remap-sink";
          opts = {
            sink_name = "amp";
            master = "onboard";
            channels = 2;
            channel_map = toChannelMap 2;
            master_channel_map = sublist 4 2 (toChannelMap channels);
            remix = false;
            sink_properties = {
              "device.description" = "Amp";
            };
            # source_properties = { "device.description" = "Amp2"; };
          };
        }
        {
          module = "remap-sink";
          opts = {
            sink_name = "headset";
            master = "onboard";
            channels = 2;
            channel_map = toChannelMap 2;
            master_channel_map = sublist 0 2 (toChannelMap channels);
            remix = false;
            sink_properties = {
              "device.description" = "Headset";
            };
            # source_properties = "device.description=Headset2";
          };
        }
        (mkIf true {
          module = "alsa-sink";
          opts = {
            sink_name = "headphones";
            device = "iec958:CARD=Generic,DEV=0";
            format = "s32";
            rate = 96000;
            channels = 2;
            channel_map = toChannelMap 2;
            tsched = false;
            #fixed_latency_range = true;
            fragment_size = 1024;
            fragments = 16;
            sink_properties = {
              "device.description" = "Headphones (Optical)";
            };
          };
        })
        (mkIf false {
          module = "alsa-sink";
          opts = {
            sink_name = "light";
            device = "iec958:CARD=Generic,DEV=0";
            format = "s32";
            rate = 48000;
            channels = 2;
            channel_map = toChannelMap 2;
            tsched = true;
            fixed_latency_range = false;
            fragment_size = 1024;
            fragments = 16;
            sink_properties = {
              "device.description" = "Optical TSched";
            };
          };
        })
        {
          module = "alsa-source";
          opts = {
            source_name = "mic";
            #device = "front:CARD=Generic,DEV=0";
            device = "hw:1,0";
            format = "s32";
            channels = 1;
            channel_map = toChannelMap 1;
            rate = 96000;
            tsched = true;
            source_properties = {
              "device.description" = "Mic";
            };
          };
        }
        {
          module = "alsa-source";
          opts = {
            source_name = "condenser";
            device = "sysdefault:CARD=Device"; # hw:2,0
            format = "float32";
            channels = 1;
            channel_map = toChannelMap 1;
            rate = 48000;
            tsched = true;
            source_properties = {
              "device.description" = "Condenser Mic";
            };
          };
        }
        (mkIf false {
          module = "alsa-source";
          opts = {
            source_name = "line";
            device = "hw:1,2";
            format = "s32";
            channels = 1;
            channel_map = toChannelMap 1;
            rate = 96000;
            tsched = true;
            source_properties = {
              "device.description" = "Line-In";
            };
          };
        })
        (mkIf true {
          module = "remap-source";
          opts = {
            source_name = "line";
            master = "mic";
            channel_map = toChannelMap 1;
            master_channel_map = toChannelMap 1;
            source_properties = {
              "device.description" = "Line-In";
            };
            remix = false;
          };
        })
        {
          module = "virtual-surround-sink";
          opts = {
            sink_name = "vsurround";
            sink_master = "headset";
            hrir = "${./files/hrir-kemar.wav}";
            sink_properties = {
              "device.description" = "Headset VSurround";
            };
            # source_properties="device.description='Headset VSurround2'"
          };
        }
        {
          module = "echo-cancel";
          opts = {
            source_master = "mic";
            sink_master = "headset";
            source_name = "mic_headset";
            sink_name = "mic_headset_sink";
            use_volume_sharing = true;
            use_master_format = true;
            channels = 1;
            aec_method = "webrtc";
            aec_args = default_aec_args // rnnoise_aec_args // {
              agc_start_volume = 150;
              #high_pass_filter = true;
              #routing_mode = "loud-earpiece"; mobile = true;
            };
          };
        }
        {
          module = "echo-cancel";
          opts = {
            source_master = "mic";
            sink_master = "speakers";
            source_name = "mic_speakers";
            sink_name = "mic_speakers_sink";
            use_volume_sharing = true;
            use_master_format = true;
            channels = 1;
            aec_method = "webrtc";
            aec_args = default_aec_args // {
              agc_start_volume = 200; # 85
              routing_mode = "loud-speakerphone"; mobile = true;
            };
          };
        }
        {
          module = "echo-cancel";
          opts = {
            source_master = "condenser";
            sink_master = "speakers";
            source_name = "condenser_speakers";
            sink_name = "condenser_speakers_sink";
            use_volume_sharing = true;
            use_master_format = true;
            channels = 1;
            aec_method = "webrtc";
            aec_args = default_aec_args // rnnoise_aec_args // {
              digital_gain_control = false;
            };
          };
        }
      ] /*(ladspa-sink {
        name = "ladspa_limiter_line";
        description = "Limiter";
        rate = 96000;
        channels = 2;
        outChannels = 2;

        opts = {
          label = "fastLookaheadLimiter"; # 1913
          plugin = "${pkgs.ladspaPlugins}/lib/ladspa/fast_lookahead_limiter_1913.so";
          #channels = 1;
          control = [
            20 # input gain (dB)
            (-1) # limit (dB)
            0.5 # release time (s)
          ];
        };
        source = {
          module = "remap-source";
          opts = {
            master = "line";
            source_name = "line_stereo";
            master_channel_map = [ "mono" "mono" ];
            channel_map = toChannelMap 2;
            remix = false;
          };
        };
      })*/ (ladspa-sink {
        name = "mic_headset_rnnoise";
        description = "RnNoise (Headset)";
        rate = 48000;
        source = "mic_headset";
        opts = {
          #label = "noise_suppressor_mono";
          #plugin = "${pkgs.rnnoise-plugin-develop}/lib/ladspa/librnnoise_ladspa.so";
          #control = [ 50 ];
          label = "mono_nnnoiseless";
          plugin = "${pkgs.ladspa-rnnoise}/lib/ladspa/libladspa_rnnoise_rs.so";
          #channels = 1;
        };
      }) (ladspa-sink {
        name = "condenser_speakers_rnnoise";
        description = "RnNoise (Condenser - Speakers)";
        rate = 48000;
        source = "condenser_speakers";
        opts = {
          label = "mono_nnnoiseless";
          plugin = "${pkgs.ladspa-rnnoise}/lib/ladspa/libladspa_rnnoise_rs.so";
        };
      }) (ladspa-sink {
        name = "condenser_rnnoise";
        description = "RnNoise (Condenser)";
        rate = 48000;
        source = "condenser";
        opts = {
          label = "mono_nnnoiseless";
          plugin = "${pkgs.ladspa-rnnoise}/lib/ladspa/libladspa_rnnoise_rs.so";
        };
      }) /*(ladspa-sink {
        name = "vocoder";
        description = "Vocoder";
        rate = 96000;
        sources = [
          #input0 source # formant
          #input1 source # carrier
          "mic_headset_rnnoise"
          {
            module = "sine-source";
            opts = {
              source_name = "ladspa_vocoder_sine";
              frequency = 1710; # default: 440
              rate = 96000;
            };
          }
        ];
        opts = {
          label = "vocoder";
          plugin = "${pkgs.vocoder-ladspa}/lib/ladspa/vocoder.so";
          control = [
            6 # band count, 1 ~ 16
            # 16 band levels, 0 ~ 1
            0.5 0.2 0.7 0.3 0.8 1.0 0.8 0.8
            0.8 0.8 0.8 0.8 0.8 0.8 0.8 0.8
          ];
        };
      })*/ [
        # TODO: multivoiceChorus 1201, amPitchshift 1433, pointerCastDistortion 1910
        {
          module = "null-sink";
          opts = {
            sink_name = "stream";
            channels = 2;
            rate = 48000;
            format = "s16";
            sink_properties = {
              "device.description" = "Stream";
            };
          };
        }
        /*{
          module = "match";
          opts.table = ${pkgs.writeText "pulse-match.table" ''
            ^sample: 32000
          ''};
        }*/
      ] (mkAfter [
        {
          module = "null-sink";
          opts = {
            sink_name = "default";
            sink_properties = {
              "device.description" = "Default Loopback";
            };
          };
        }
        {
          module = "loopback";
          opts = {
            source = "default.monitor";
            sink = "@DEFAULT_SINK@";
            source_dont_move = true;
            remix = true;
          };
        }
        {
          module = "combine-sink";
          opts = {
            sink_name = "stream_echo";
            slaves = [ "default" "stream" ];
            resample_method = "speex-float-1";
            sink_properties = {
              "device.description" = "Stream (Echo)";
            };
          };
        }
      ]) ];
      defaults = {
        source = "mic";
        #sink = "alsa_output.${usb}.analog-stereo";
        #source = "alsa_input.${usb}.mono-fallback";
      };
    };

    services.udev.extraRules = ''
      # my VM disks
      SUBSYSTEM=="block", ACTION=="add", ATTRS{model}=="INTEL SSDSC2BP48", ATTRS{wwid}=="naa.55cd2e404b6f84e5", OWNER="arc"
      SUBSYSTEM=="block", ACTION=="add", ATTR{partition}=="4", ATTR{size}=="125829120", ATTRS{wwid}=="eui.6479a741e0203d76", OWNER="arc"
      SUBSYSTEM=="block", ACTION=="add", ATTR{partition}=="6", ATTR{size}=="134217728", ATTRS{wwid}=="eui.002303563000ad1b", OWNER="arc"
      # uvc devices
      KERNEL=="video[0-9]*", SUBSYSTEM=="video4linux", SUBSYSTEMS=="usb", ATTR{index}=="0", ATTRS{idVendor}=="0c45", ATTRS{idProduct}=="6366", ATTRS{product}=="USB Live camera", SYMLINK+="video-hd682h", TAG+="systemd"
      KERNEL=="video[0-9]*", SUBSYSTEM=="video4linux", SUBSYSTEMS=="usb", ATTR{index}=="0", ATTRS{idVendor}=="0c45", ATTRS{idProduct}=="6366", ATTRS{product}=="USB  Live camera", SYMLINK+="video-hd826", TAG+="systemd"
    '';
    hardware.display = {
      enable = true;
      monitors = (import ./displays.nix { inherit lib; }).default config.hardware.display.monitors;
    };
    services.xserver = {
      displayManager = {
        startx.enable = mkForce false;
        lightdm = {
          # TODO: switch to lxdm?
          enable = true;
        };
        session = singleton {
          manage = "desktop";
          name = "xsession";
          start = ''
            ${pkgs.runtimeShell} ~/.xsession &
            waitPID=$!
          '';
        };
      };
      deviceSection = mkMerge [
        # NOTE: this is decimal, be careful! IDs are typically shown in hex
        #''BusID "PCI:39:0:0"'' # primary GPU
        #''BusID "PCI:40:0:0"'' # secondary GPU
        ''BusID "PCI:05:0:0"'' # tertiary (chipset slot) GPU
      ];
    };

    boot = {
      extraModulePackages = [ config.boot.kernelPackages.v4l2loopback.out ];
      modprobe.modules = {
        vfio-pci = let
          vfio-pci-ids = [
            # "10de:1c81" "10de:0fb9" # 1050
            # "10de:1f82" "10de:10fa" # 1660
            "10de:2206" "10de:1aef" # 3080
          ];
        in mkIf (config.home.profiles.vfio && vfio-pci-ids != [ ]) {
          options.ids = concatStringsSep "," vfio-pci-ids;
        };
        v4l2loopback.options = {
          # https://github.com/umlaeute/v4l2loopback/blob/main/README.md
          devices = 8;
        };
      };
      loader = {
        generationsDir = {
          copyKernels = true;
        };
        systemd-boot.enable = true;
        efi = {
          canTouchEfiVariables = false;
          efiSysMountPoint = "/mnt/efi";
        };
      };
      supportedFilesystems = ["btrfs" "xfs"];
      tmpOnTmpfsSize = "64G";
    };
    services.journald.extraConfig = ''
      SystemMaxUse=3G
    '';

    fileSystems = {
      "/mnt/old" = {
        device = "/dev/disk/by-uuid/4a260bff-eac5-40c9-8c40-00f0557b5923";
        fsType = "btrfs";
        options = [ "x-systemd.automount" "noauto" "rw" "relatime" "user_subvol_rm_allowed" "compress=zstd" "ssd" "space_cache" "subvol=/" "nofail" ];
      };
      "/nix" = {
        device = "/dev/disk/by-uuid/a82e1a40-e0e5-4461-a29d-42caf5a502b6";
        fsType = "xfs";
        options = ["rw" "relatime"]; # discard
      };
      "/boot" = {
        device = "/mnt/efi/EFI/nixos";
        fsType = "none";
        options = ["bind"];
      };
      "/mnt/bigdata" = {
        device = "/dev/disk/by-uuid/2354ffd4-67b6-49e6-90f1-22cc2a116ff1";
        fsType = "btrfs";
        options = [ "x-systemd.automount" "noauto" "rw" "strictatime" "lazytime" "user_subvol_rm_allowed" "compress=zstd" "space_cache" "autodefrag" "subvol=/bigdata" "nofail" ];
      };
      "/" = {
        device = "/dev/disk/by-uuid/76b9ccba-7d5f-4ceb-b0aa-476c63ebb60f";
        fsType = "btrfs";
        options = [ "rw" "relatime" "user_subvol_rm_allowed" "compress=zstd" "ssd" "space_cache" "subvol=/" ];
      };
      "/mnt/enc" = {
        device = "/dev/mapper/enc";
        fsType = "xfs";
        options = [ "x-systemd.automount" "noauto" ];
        encrypted = {
          enable = false;
          label = "enc";
          blkDev = "/dev/disk/by-uuid/cc8e597e-228d-49b6-af65-a47ced8dd57a"; # PARTLABEL=shanghai-enc
        };
        crypttab = {
          enable = true;
          options = [
            "luks" "discard" "noauto" "nofail"
          ];
        };
      };
      "/home/arc" = {
        device = "/mnt/enc/home/arc";
        fsType = "none";
        options = [ "bind" "x-systemd.automount" "noauto" "nofail" ];
        depends = [ "/mnt/enc" ];
      };
      "/mnt/data" = {
        device = "/dev/disk/by-uuid/9407fd0a-683b-4839-908d-e65cb9b5fec5";
        fsType = "btrfs";
        options = ["rw" "strictatime" "lazytime" "user_subvol_rm_allowed" "compress=zstd" "ssd" "space_cache" "subvol=/" "nofail"];
      };
      "/mnt/efi-old" = {
        device = "/dev/disk/by-uuid/D460-0EF6";
        fsType = "vfat";
        options = [ "x-systemd.automount" "noauto" "rw" "strictatime" "lazytime" "errors=remount-ro" "nofail" ];
      };
      "/mnt/efi" = {
        device = "/dev/disk/by-uuid/1016-9B5D";
        fsType = "vfat";
        options = ["rw" "strictatime" "lazytime" "errors=remount-ro"];
      };
      "/mnt/wdarchive" = {
        device = "/dev/disk/by-uuid/da37f8cd-9934-4d08-b0cf-a4d5ead43454";
        fsType = "ext4";
        options = [ "x-systemd.automount" "noauto" ];
      };
      "/mnt/wdworking" = {
        device = "/dev/disk/by-uuid/64629b8d-8eae-4a00-87b2-d3fe2763cf34";
        fsType = "ext4";
        options = [ "x-systemd.automount" "noauto" ];
      };
      "/mnt/wdmisc" = {
        device = "/dev/disk/by-uuid/d2c686b4-b7e1-4866-a8e9-efaa7964cbe5";
        fsType = "ext4";
        options = [ "x-systemd.automount" "noauto" ];
      };
    };
    swapDevices = [
      {
        # 72G Plextor
        device = "/dev/disk/by-partuuid/38b62f92-2fa2-4ee3-9e20-77a77a8e2b31";
        randomEncryption.enable = true;
      }
      {
        # 16G BPX
        device = "/dev/disk/by-partuuid/8a7fdfac-14bc-431e-9907-1069ec937e88";
        randomEncryption.enable = true;
      }
      {
        # 16G sabrent
        device = "/dev/disk/by-partuuid/0ecca923-20db-c34b-807b-2be849bf2017";
        randomEncryption.enable = true;
      }
    ];
  };
}
