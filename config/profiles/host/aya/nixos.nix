{ name, pkgs, config, lib, ... }: with lib; {
  imports = [
    ./ayacam.nix
    ../../../../hw/pinecube
    ../../../../cfg/gensokyo.nix
    ../../../../cfg/trusted.nix
  ];

  config = {
    system.stateVersion = "22.05";
    home.minimalSystem = true;
    deploy.tf.deploy = {
      gcroot.enable = true;
      systems.aya.connection.host = config.deploy.network.local.ipv4;
    };

    networking = {
      hostId = "c59d5b70";
      useDHCP = false;
      interfaces.eth0 = {
        macAddress = "86:4a:9d:6a:a9:04";
        ipv4 = {
          addresses = [
            {
              address = config.deploy.network.local.ipv4;
              prefixLength = 24;
            }
          ];
          routes = [
            {
              address = "0.0.0.0";
              prefixLength = 0;
              via = "10.1.1.1";
            }
          ];
        };
      };
      firewall = {
        allowedTCPPortRanges = [
          { from = 8000; to = 9000; }
        ];
        allowedUDPPortRanges = [
          { from = 8000; to = 9000; }
        ];
      };
    };

    deploy.network.local.ipv4 = "10.1.1.62";
    services.openssh.ports = [ 22 62022 ];
    nix.gc = {
      automatic = true;
      options = "-d"; # actually delete old things
    };

    users.users = {
      arc = {
        extraGroups = [ "wheel" "networkmanager" "video" ];
      };
      root.shell = mkForce pkgs.bash;
    };
    home-manager.users.root.programs.zsh.enable = mkForce false;
    services.getty.autologinUser = "root";
    services.journald.extraConfig = ''
      SystemMaxUse=128M
    '';

    environment.systemPackages = with pkgs; with gst_all_1; [
      ffmpeg
      v4l_utils
      usbutils
      gstreamer
      gst-rtsp-launch
    ];
    environment.sessionVariables = {
      GST_PLUGIN_SYSTEM_PATH_1_0 = with pkgs; with gst_all_1; lib.makeSearchPath "lib/gstreamer-1.0" [
        gstreamer.out
        gst-plugins-base gst-plugins-good gst-plugins-bad gst-plugins-ugly
        gst-jpegtrunc
      ];
    };

    sound.enable = false;
    networking.wireless.enable = false; # just use physical ethernet
    zramSwap.enable = true; # 128MB is not much to work with
    services.ayacam.enable = true;
  };
}
