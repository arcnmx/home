{ tf, config, pkgs, lib, ... }: with lib; {
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
        # https://wiki.archlinux.org/index.php/PulseAudio/Troubleshooting#Enable_Echo.2FNoise-Cancellation
        analog_gain_control = false;
        digital_gain_control = true;
        noise_suppression = true;
        high_pass_filter = false;
        extended_filter = true;
        experimental_agc = true;
        intelligibility_enhancer = false;
      };
      usb = "usb-C-Media_Electronics_Inc._USB_Audio_Device-00";
      channels = 4; # NOTE: first two channels include an amp for headphones, 3rd needs an external amp
      channel_map =
        [ "front-left" "front-right" "rear-left" "rear-right" "side-left" "side-right" ];
    in {
      loadModule = [
        # "mmkbd-evdev"
        {
          module = "alsa-sink";
          opts = {
            sink_name = "onboard";
            device = "surround40:CARD=Generic,DEV=0";
            format = "s32";
            rate = 48000;
            inherit channels;
            channel_map =
              sublist 0 4 channel_map
              ++ optional (channels == 5) [ "lfe" ]
              ++ optionals (channels == 6) (sublist channel_map 4 2);
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
            channel_map = sublist 0 2 channel_map;
            master_channel_map = sublist 2 2 channel_map;
            remix = "no";
            sink_properties = {
              "device.description" = "Speakers";
            };
            # source_properties = "device.description=Speakers2";
          };
        }
        {
          module = "remap-sink";
          opts = {
            sink_name = "dac";
            master = "onboard";
            channels = 2;
            channel_map = sublist 0 2 channel_map;
            master_channel_map = sublist 4 2 channel_map;
            remix = "no";
            sink_properties = {
              "device.description" = "DAC";
            };
            # source_properties = { "device.description" = "DAC2"; };
          };
        }
        {
          module = "remap-sink";
          opts = {
            sink_name = "headset";
            master = "onboard";
            channels = 2;
            channel_map = sublist 0 2 channel_map;
            master_channel_map = sublist 0 2 channel_map;
            remix = "no";
            sink_properties = {
              "device.description" = "Headset";
            };
            # source_properties = "device.description=Headset2";
          };
        }
        {
          module = "alsa-sink";
          opts = {
            sink_name = "headphones";
            device = "iec958:CARD=Generic,DEV=0";
            format = "s32";
            rate = 96000;
            channels = 2;
            channel_map = sublist 0 2 channel_map;
            tsched = false;
            #fixed_latency_range = true;
            fragment_size = 1024;
            fragments = 16;
            sink_properties = {
              "device.description" = "Headphones (Optical)";
            };
          };
        }
        {
          module = "alsa-sink";
          opts = {
            sink_name = "light";
            device = "iec958:CARD=Generic,DEV=0";
            format = "s32";
            rate = 48000;
            channels = 2;
            channel_map = sublist 0 2 channel_map;
            tsched = true;
            fixed_latency_range = false;
            fragment_size = 1024;
            fragments = 16;
            sink_properties = {
              "device.description" = "Optical TShed";
            };
          };
        }
        {
          module = "alsa-source";
          opts = {
            source_name = "mic";
            device = "front:CARD=Generic,DEV=0";
            format = "s32";
            rate = 96000;
            tsched = true;
          };
        }
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
            aec_args = default_aec_args // {
              agc_start_volume = 150;
              #high_pass_filter = true;
              #routing_mode = "loud-earpiece";
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
              #routing_mode = "loud-speakerphone";
            };
          };
        }
      ];
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
    };

    fileSystems = {
      "/" = {
        device = "/dev/disk/by-uuid/4a260bff-eac5-40c9-8c40-00f0557b5923";
        fsType = "btrfs";
        options = ["rw" "relatime" "user_subvol_rm_allowed" "compress=zstd" "ssd" "space_cache" "subvol=/"];
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
        options = ["rw" "strictatime" "lazytime" "user_subvol_rm_allowed" "compress=zstd" "space_cache" "autodefrag" "subvol=/bigdata" "nofail"];
      };
      "/mnt/data" = {
        device = "/dev/disk/by-uuid/9407fd0a-683b-4839-908d-e65cb9b5fec5";
        fsType = "btrfs";
        options = ["rw" "strictatime" "lazytime" "user_subvol_rm_allowed" "compress=zstd" "ssd" "space_cache" "subvol=/" "nofail"];
      };
      "/mnt/efi" = {
        device = "/dev/disk/by-uuid/D460-0EF6";
        fsType = "vfat";
        options = ["rw" "strictatime" "lazytime" "errors=remount-ro"];
      };
    };
    swapDevices = [
      { device = "/dev/disk/by-uuid/4faab83b-164e-444c-b1b6-4a26e7f7e6bf"; }
    ];
  };
}
