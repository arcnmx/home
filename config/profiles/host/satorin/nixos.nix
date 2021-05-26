{ pkgs, config, lib, ... }: with lib; {
  options.home = {
    profiles.host.satorin = mkEnableOption "hostname: satorin";
  };

  config = mkIf config.home.profiles.host.satorin {
    home.profiles.trusted = true;
    home.profiles.personal = true;
    home.profiles.gui = true;
    home.profiles.hw.xps13 = true;
    home.profiles.host.gensokyo = true;
    deploy.tf.deploy.systems.satorin.connection.host = config.deploy.network.local.ipv4;

    networking = {
      hostId = "451b608e";
      nftables.ruleset = mkAfter (builtins.readFile ./files/nftables.conf);
      useNetworkd = true;
      useDHCP = false;
    };

    deploy.network.local.ipv4 = "10.1.1.64";
    services.openssh.ports = [ 22 64022 ];
    #networking.connman.extraFlags = ["-I" "eth0" "-I" "wlan0"]; # why did I have this there? these don't even exist?

    boot = {
      kernelParams = ["zfs.zfs_arc_max=${toString (512*1024*1024)}"];
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
      supportedFilesystems = ["zfs"];
      zfs = {
        enableUnstable = true;
        requestEncryptionCredentials = true;
      };
    };
    nixpkgs.overlays = singleton (self: super: {
      # enable zfsUnstable on unsupported kernel versions
      linuxPackagesOverlays = super.linuxPackagesOverlays or [ ]
      ++ singleton self.kernelPatches.overlays.zfsVersionOverride;
    });
    systemd.watchdog.enable = false;
    home.hw.xps13.wifi = "ax210";
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
    services.zfs = {
      autoScrub = {
        enable = true;
        interval = "*-*-01 05:00:00"; # 1st of the month at 5am
      };
    };

    fileSystems = {
      "/" = {
        device = "satorin/root/nixos";
        fsType = "zfs";
      };
      "/home" = {
        device = "satorin/root/home";
        fsType = "zfs";
      };
      "/boot" = {
        device = "/mnt/efi/EFI/nixos";
        fsType = "none";
        options = ["bind"];
      };
      "/mnt/efi" = {
        device = "/dev/disk/by-uuid/17CA-FD91";
        fsType = "vfat";
        options = ["rw" "strictatime" "lazytime" "errors=remount-ro"];
      };
    };
    swapDevices = [
      { device = "/dev/disk/by-partuuid/a1ec1791-770e-4541-9945-33fc64c4d2cf"; }
    ];
  };
}
