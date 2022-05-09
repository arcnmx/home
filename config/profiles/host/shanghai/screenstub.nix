{ config, lib, ... }: with lib; let
  cfg = config.programs.screenstub;
  inherit (config.home.nixosConfig.hardware.display) monitors;
  host_ddc = singleton {
    guest_exec = [ "C:/Apps/ddcset.exe" "0x60" "0x{:x}" ];
  };
  guest_ddc = [
    "guest_wait"
    "ddc"
  ];
  swapDisplay = configName: singleton {
    guest_exec = [
      "C:/Apps/dc2.exe" "-configure=C:/Apps/${configName}.xml" "-temporary"
    ];
  };
  monitorFor = monitor: {
    inherit (monitor.edid) manufacturer model;
    xrandr_name = monitor.output;
  };
in {
  options.home.profileSettings.shanghai = {
    eveDdc = mkEnableOption "Eve DDC"; # this doesn't even work yet wtf .-.
  };
  config.programs.screenstub = mkIf config.home.profiles.host.shanghai {
    settings = {
      screens = [
        {
          # Eve Spectrum 4K
          x_instance = "Spectrum";
          monitor = monitorFor monitors.spectrum;
          host_source.name = monitors.spectrum.source;
          guest_source.name = "HDMI-1"; # DisplayPort-2 (USB Type-C is broken atm .-.)
          ddc = {
            minimal_delay = "5300ms"; # test/reduce once ddc is working
            host = optionals config.home.profileSettings.shanghai.eveDdc host_ddc;
            guest = optionals config.home.profileSettings.shanghai.eveDdc guest_ddc;
          };
        }
        /*{
          # BenQ 1440p
          x_instance = "BenQ";
          ddc = {
            minimal_delay = "5300ms"; # this is never consistent :<
            host = singleton "ddc";
            guest = singleton "ddc";
          };
          monitor = {
            manufacturer = "BNQ";
            model = "BenQ EX2780Q";
            xrandr_name = "DP-0";
          };
          guest_source.name = "DisplayPort-1";
          host_source.name = "DisplayPort-2";
        }*/
        {
          # Dell 4K
          x_instance = "Dell";
          monitor = monitorFor monitors.dell;
          host_source.name = monitors.dell.source;
          guest_source.name = "DisplayPort-1";
          ddc = {
            minimal_delay = "800ms";
            host = singleton "ddc"; # host_ddc?
            guest = singleton "ddc";
          };
        }
        {
          # LG 4K
          x_instance = "LG";
          monitor = monitorFor monitors.lg;
          host_source.name = monitors.lg.source;
          guest_source.name = "HDMI-1";
          ddc = {
            minimal_delay = "100ms";
            host = host_ddc;
            guest = guest_ddc;
          };
        }
      ];
      key_remap = {
        # https://docs.rs/input-linux/*/input_linux/enum.Key.html
        Calc = "Reserved";
        Mail = "Reserved";
        Config = "Reserved";
      };
      hotkeys = [
        {
          triggers = singleton "Num1";
          modifiers = singleton cfg.modifierKey;
          events = swapDisplay "dell";
        }
        {
          triggers = singleton "Num2";
          modifiers = singleton cfg.modifierKey;
          events = swapDisplay "eve"; # benq
        }
        {
          triggers = singleton "Num3";
          modifiers = singleton cfg.modifierKey;
          events = swapDisplay "lg";
        }
        {
          triggers = singleton "Num9";
          modifiers = singleton cfg.modifierKey;
          events = swapDisplay "eve-portrait";
        }
        {
          triggers = singleton "Equal";
          modifiers = singleton cfg.modifierKey;
          events = singleton {
            guest_exec = [
              "C:/Apps/heater.bat"
            ];
          };
        }
        {
          triggers = singleton "RightCtrl";
          modifiers = singleton "LeftMeta";
          events = [
            {
              toggle_grab.x = {
                mouse = false;
                ignore = [ ];
              };
            }
            {
              toggle_grab.evdev = {
                #new_device_name = "testing";
                #evdev_ignore = singleton "button";
                xcode_ignore = [ "button" "absolute" ];
                devices = singleton "/dev/input/by-id/usb-Razer_Razer_Naga_Trinity_00000000001A-event-mouse";
              };
            }
            # "unstick_host"
          ];
        }
      ];
    };
  };
}
