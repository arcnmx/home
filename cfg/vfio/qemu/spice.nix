{ config, lib, ... }: with lib; let
  cfg = config.spice;
in {
  options.spice = {
    enable = mkEnableOption "SPICE";
    bus = mkOption {
      type = types.str;
    };
    slot = mkOption {
      type = types.int;
      default = 0;
    };
    path = mkOption {
      type = types.path;
      default = config.state.runtimePath + "/spice";
    };
    usb = {
      enable = mkEnableOption "USB" // {
        default = true;
      };
    };
    vga = {
      enable = mkEnableOption "VGA";
    };
  };
  config = mkIf cfg.enable (mkMerge [
    {
      args.display = "none";
      cli.spice.settings = {
        unix = true;
        disable-ticketing = true;
        addr = cfg.path;
      };
      chardevs.spice0.settings = {
        id = "spice0sock";
        backend = "spicevmc";
        name = "vdagent";
      };
      devices.spice0 = {
        cli.dependsOn = [ config.chardevs.spice0.id cfg.bus ];
        settings = {
          driver = "virtserialport";
          name = "com.redhat.spice.0";
          chardev = config.chardevs.spice0.id;
          bus = "${cfg.bus}.${toString cfg.slot}";
        };
      };
    }
    (mkIf cfg.vga.enable {
      pci.devices.qxl.settings.driver = "qxl-vga";
    })
    (mkIf cfg.usb.enable {
      chardevs = {
        spiceusb1.settings = {
          backend = "spicevmc";
          name = "usbredir";
        };
        spiceusb2.settings = {
          backend = "spicevmc";
          name = "usbredir";
        };
        spiceusb3.settings = {
          backend = "spicevmc";
          name = "usbredir";
        };
      };
      devices = {
        spiceusb1-dev = {
          cli.dependsOn = [
            config.usb.bus
            config.chardevs.spiceusb1.id
          ];
          settings = {
            driver = "usb-redir";
            chardev = config.chardevs.spiceusb1.id;
          };
        };
        spiceusb2-dev = {
          cli.dependsOn = [
            config.usb.bus
            config.chardevs.spiceusb2.id
          ];
          settings = {
            driver = "usb-redir";
            chardev = config.chardevs.spiceusb2.id;
          };
        };
        spiceusb3-dev = {
          cli.dependsOn = [
            config.usb.bus
            config.chardevs.spiceusb3.id
          ];
          settings = {
            driver = "usb-redir";
            chardev = config.chardevs.spiceusb3.id;
          };
        };
      };
    })
  ]);
}
