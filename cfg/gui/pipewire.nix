{ config, lib, ... }: with lib; let
  cfg = config.services.pipewire;
  mapConfSetting = filename: conf: nameValuePair "pipewire/${filename}.conf" (mkIf (conf != null) {
    text = builtins.toJSON conf;
  });
  mkOptionDefaults = mapAttrs (_: mkOptionDefault);
  mkEarly = mkOrder 750;
in {
  options.services.pipewire = with types; {
    confSettings = mkOption {
      type = attrsOf (nullOr json.types.attrs);
      default = { };
    };
  };
  config = {
    services.pipewire = {
      confSettings = {
        pipewire = {
          "context.properties" = mkOptionDefaults {
            "link.max-buffers" = 16;
            "core.daemon" = true;
            "core.name" = "pipewire-0";
          };
          "context.spa-libs" = mkOptionDefaults {
            "audio.convert.*" = "audioconvert/libspa-audioconvert";
            "avb.*" = "avb/libspa-avb";
            "api.alsa.*" = "alsa/libspa-alsa";
            "api.v4l2.*" = "v4l2/libspa-v4l2";
            "api.libcamera.*" = "libcamera/libspa-libcamera";
            "api.bluez5.*" = "bluez5/libspa-bluez5";
            "api.vulkan.*" = "vulkan/libspa-vulkan";
            "api.jack.*" = "jack/libspa-jack";
            "support.*" = "support/libspa-support";
          };
          "context.modules" = mkEarly [
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
            {
              name = "libpipewire-module-x11-bell";
              flags = [ "ifexists" "nofail" ];
            }
          ];
          "context.objects" = mkEarly [
            {
              #  A default dummy driver. This handles nodes marked with the "node.always-driver" property when no other driver is currently active
              factory = "spa-node-factory";
              args = {
                "factory.name" = "support.node.driver";
                "node.name" = "Dummy-Driver";
                "node.group" = "pipewire.dummy";
                "priority.driver" = 20000;
              };
            }
            {
              factory = "spa-node-factory";
              args = {
                "factory.name" = "support.node.driver";
                "node.name" = "Freewheel-Driver";
                "priority.driver" = 19000;
                "node.group" = "pipewire.freewheel";
                "node.freewheel" = true;
              };
            }
          ];
        };
        pipewire-pulse = {
          "context.properties" = { };
          "context.spa-libs" = mkOptionDefaults {
            "audio.convert.*" = "audioconvert/libspa-audioconvert";
            "support.*" = "support/libspa-support";
          };
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
            { name = "libpipewire-module-protocol-pulse"; }
          ];
          "pulse.cmd" = mkEarly [
            { cmd = "load-module"; args = "module-always-sink"; flags = [ ]; }
          ];
          "pulse.properties" = {
            "server.address" = mkEarly [
              "unix:native"
            ];
          };
          "pulse.rules" = mkEarly [
            {
              # skype does not want to use devices that don't have an S16 sample format.
              matches = [
                { "application.process.binary" = "teams"; }
                { "application.process.binary" = "teams-insiders"; }
                { "application.process.binary" = "skypeforlinux"; }
              ];
              actions.quirks = [ "force-s16-info" ];
            }
            {
              # firefox marks the capture streams as don't move and then they
              # can't be moved with pavucontrol or other tools.
              matches = singleton { "application.process.binary" = "firefox"; };
              actions.quirks = [ "remove-capture-dont-move" ];
            }
            {
              # speech dispatcher asks for too small latency and then underruns.
              matches = singleton { "application.name" = "~speech-dispatcher.*"; };
              actions.update-props = {
                "pulse.min.req" = "512/48000"; # 10.6ms
                "pulse.min.quantum" = "512/48000"; # 10.6ms
                "pulse.idle.timeout" = 5; # pause after 5 seconds of underrun
              };
            }
          ];
          "stream.properties" = {
          };
        };
      };
    };
    environment.etc = optionalAttrs cfg.enable (mapAttrs' mapConfSetting cfg.confSettings);
  };
}
