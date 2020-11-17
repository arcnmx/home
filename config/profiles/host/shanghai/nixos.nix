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
    home.profiles.hw.x370gpc = true;

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
      dns.records = {
        hourai = {
          inherit (tf.dns.records.local_a) tld;
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
    services.openssh.ports = [ 22 32022 ];
    hardware.openrazer.enable = true;
    hardware.pulseaudio.extraConfig = let
      usb = "usb-C-Media_Electronics_Inc._USB_Audio_Device-00";
      load-module = { module, opts ? { } }: "load-module module-${module}" +
        optionalString (opts != { }) (" " + concatStringsSep " " (mapAttrsToList (k: v: "${k}=${toString v}") opts));
      default_aec_args = {
        # https://wiki.archlinux.org/index.php/PulseAudio/Troubleshooting#Enable_Echo.2FNoise-Cancellation
        analog_gain_control = 0;
        digital_gain_control = 1;
        noise_suppression = 1;
        high_pass_filter = 0;
        extended_filter = 1;
        experimental_agc = 1;
        intelligibility_enhancer = 0;
      };
      aec_args = opts: ''"${concatStringsSep " " (mapAttrsToList (k: v: "${k}=${toString v}") opts)}"'';
      modules = [ {
        # { module = "mmkbd-evdev"; }
        module = "alsa-sink";
        opts = {
          sink_name = "onboard";
          device = "surround40:CARD=Generic,DEV=0";
          format = "s32";
          rate = 48000;
          channels = 6;
          channel_map = "front-left,front-right,rear-left,rear-right,center,lfe";
          tsched = 1;
          fixed_latency_range = 0;
          fragment_size = 1024;
          fragments = 16;
        };
      } {
        module = "alsa-sink";
        opts = {
          sink_name = "onboard";
          device = "surround40:CARD=Generic,DEV=0";
          format = "s32";
          rate = 48000;
          channels = 6;
          channel_map = "front-left,front-right,rear-left,rear-right,center,lfe";
          tsched = 1;
          fixed_latency_range = 0;
          fragment_size = 1024;
          fragments = 16;
        };
      } {
        module = "alsa-source";
        opts = {
          source_name = "mic";
          device = "front:CARD=Generic,DEV=0";
          format = "s32";
          rate = 96000;
          tsched = 1;
        };
      } {
        module = "remap-sink";
        opts = {
          sink_name = "speakers";
          master = "onboard";
          channels = 2;
          channel_map = "front-left,front-right";
          master_channel_map = "rear-left,rear-right";
          remix = "no";
          sink_properties = "device.description=Speakers";
          # source_properties = "device.description=Speakers2";
        };
      } {
        module = "remap-sink";
        opts = {
          sink_name = "headphones";
          master = "onboard";
          channels = 2;
          channel_map = "front-left,front-right";
          master_channel_map = "center,lfe";
          remix = "no";
          sink_properties = "device.description=Headphones";
          # source_properties = "device.description=Headphones2";
        };
      } {
        module = "remap-sink";
        opts = {
          sink_name = "headset";
          master = "onboard";
          channels = 2;
          channel_map = "front-left,front-right";
          master_channel_map = "front-left,front-right";
          remix = "no";
          sink_properties = "device.description=Headset";
          # source_properties = "device.description=Headset2";
        };
      } {
        module = "virtual-surround-sink";
        opts = {
          sink_name = "vsurround";
          sink_master = "headset";
          hrir = "${./files/hrir-kemar.wav}";
          sink_properties = ''"device.description='Headset VSurround'"'';
          # source_properties="device.description='Headset VSurround2'"
        };
      } {
        module = "echo-cancel";
        opts = {
          source_master = "mic";
          sink_master = "headset";
          source_name = "mic_headset";
          sink_name = "mic_headset_sink";
          use_volume_sharing = 1;
          use_master_format = 1;
          channels = 1;
          aec_method = "webrtc";
          aec_args = aec_args (default_aec_args // {
            agc_start_volume = 150;
            #high_pass_filter = 1;
            #routing_mode = "loud-earpiece";
          });
        };
      } {
        module = "echo-cancel";
        opts = {
          source_master = "mic";
          sink_master = "speakers";
          source_name = "mic_speakers";
          sink_name = "mic_speakers_sink";
          use_volume_sharing = 1;
          use_master_format = 1;
          channels = 1;
          aec_method = "webrtc";
          aec_args = aec_args (default_aec_args // {
            agc_start_volume = 200; # 85
            #routing_mode = "loud-speakerphone";
          });
        };
      } ];
    in mkMerge (
      (map load-module modules) ++ [
        "set-default-source mic"
        #"set-default-sink alsa_output.${usb}.analog-stereo"
        #"set-default-source alsa_input.${usb}.mono-fallback"
      ]
    );

    services.udev.extraRules = ''
      SUBSYSTEM=="module", ACTION=="add", KERNEL=="acpi_cpufreq", RUN+="${pkgs.runtimeShell} -c 'for x in /sys/devices/system/cpu/cpufreq/*/scaling_governor; do echo performance > $$x; done'"

      # my VM disks
      SUBSYSTEM=="block", ACTION=="add", ATTRS{model}=="INTEL SSDSC2BP48", ATTRS{wwid}=="*BTJR442300QQ480BGN*", OWNER="arc"
      SUBSYSTEM=="block", ACTION=="add", ATTR{partition}=="6", ATTR{size}=="134217728", ATTRS{wwid}=="eui.002303563000ad1b", OWNER="arc"
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
        ''BusID "PCI:37:0:0"'' # tertiary (chipset slot) GPU
      ];
    };

    boot = mkMerge [ {
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
      supportedFilesystems = ["btrfs"];
    } (let
      vfio-pci-ids = [
        # "10de:1c81" "10de:0fb9" # 1050
        # "10de:1f82" "10de:10fa" # 1660
        "10de:2206" "10de:1aef" # 3080
      ];
    in mkIf config.home.profiles.vfio {
      # TODO: extraModprobeConfig does not seem to be placed in initrd, see: https://github.com/NixOS/nixpkgs/issues/25456
      kernelParams = mkIf (vfio-pci-ids != [ ]) [
        "vfio-pci.ids=${concatStringsSep "," vfio-pci-ids}"
      ];
    }) ];

    fileSystems = {
      "/" = {
        device = "/dev/disk/by-uuid/4a260bff-eac5-40c9-8c40-00f0557b5923";
        fsType = "btrfs";
        options = ["rw" "relatime" "user_subvol_rm_allowed" "compress=zstd" "ssd" "space_cache" "subvol=/"];
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
