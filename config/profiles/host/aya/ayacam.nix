{ config, lib, pkgs, ... }: with lib; let
  cfg = config.services.ayacam;
in {
  options.services.ayacam = {
    enable = mkEnableOption "ayacam";
    port = mkOption {
      type = types.port;
      default = 9001;
    };
    width = mkOption {
      type = types.int;
      default = 1920;
    };
    height = mkOption {
      type = types.int;
      default = 1080;
    };
  };
  config = mkIf cfg.enable {
    systemd.sockets.gststream = {
      listenStreams = [ "0.0.0.0:${toString cfg.port}" ];
      socketConfig = {
        # if only I knew how to link this to multisocketsink
        Accept = true;
        Backlog = 0;
        MaxConnections = 1;
      };
      wantedBy = [ "sockets.target" ];
    };
    systemd.services."gststream@" = let
      resolution = concatMapStringsSep "x" toString [ cfg.width cfg.height ];
      framerate = 30;
      i2cbus = "1";
      i2caddr = "0x3c";
      i2cvalues = [
        { reg = [ "0x47" "0x13" ]; value = "0x03"; } # jpeg mode
        { reg = [ "0x44" "0x07" ]; value = "0x07"; } # quant scale (lower = higher qual 0x04~0x0f?)
        # TODO: adjust qual/scale based on resolution, mainly limited by file size over 100mbit eth
      ];
      i2cset = concatMapStringsSep "\n" ({ reg, value }:
        "${pkgs.i2c-tools}/bin/i2cset -y -f ${i2cbus} ${i2caddr} ${toString reg} ${value} i || true"
      ) i2cvalues;
      pipeline = [
        "v4l2src"
        { caps."image/jpeg" = {
          inherit (cfg) width height;
          framerate = "${toString framerate}/1";
        }; }
        { element.queue = {
          leaky = "downstream";
          max-size-buffers = 2;
          max-size-bytes = 0;
          max-size-time = 0;
        }; }
        "jpegtrunc"
        { element.matroskamux.streamable = true; }
        { element.fdsink = {
          fd = 3; # SD_LISTEN_FDS_START
          sync = false;
        }; }
      ];
    in {
      environment = {
        inherit (config.environment.sessionVariables) GST_PLUGIN_SYSTEM_PATH_1_0;
      };
      preStart = ''
        ${pkgs.v4l_utils}/bin/media-ctl --set-v4l2 '"ov5640 1-003c":0[fmt:JPEG_1X8/${resolution}@1/${toString framerate}]'
      '';
      # have to i2c config *after* capture from v4l2 has started :<
      # consider in future: part of gst pipeline can send data to another socket activation, which triggers this script
      postStart = ''
        sleep 5
        ${i2cset}
      '';
      script = ''
        exec ${pkgs.gst_all_1.gstreamer.dev}/bin/gst-launch-1.0 -e --no-position ${pkgs.lib.gst.pipelineShellString pipeline}
      '';
    };

    networking.firewall.allowedTCPPorts = singleton cfg.port;
  };
}
