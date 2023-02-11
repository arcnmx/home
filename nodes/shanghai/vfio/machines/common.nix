{ nixosConfig, config, lib, ... }: with lib; let
  pciAddrs = let
    bus = config.pci.devices.pci2.settings.id;
  in rec {
    hostnet0.addr = "0x2";
    sound0.addr = "0x3";
    scsi0.addr = "0x4";
    usb3.addr = "0x5";
    lookingGlass.addr = "0x6";
    scream.addr = "0x7";
    gpu = {
      multifunction = true;
      addr = "0x8";
    };
    gpu-audio = {
      device.cli.dependsOn = [ config.devices.gpu.settings.id ];
      addr = gpu.addr + ".0x1";
    };
    pci2.addr = "0x9";
    balloon0 = {
      inherit bus;
      addr = "0x1";
    };
    rng0 = {
      inherit bus;
      addr = "0x2";
    };
    smbnet0 = {
      inherit bus;
      addr = "0x3";
    };
    vserial0 = {
      inherit bus;
      addr = "0x4";
    };
    natnet0.addr = "0xd";
    bridge.addr = "0xe";
    hostusb.addr = "0xf";
  };
  iothreads = { config, ... }: {
    config.objects = listToAttrs (genList (i: nameValuePair "io${toString i}" {
      settings.typename = "iothread";
    }) (nixosConfig.hardware.cpu.info.cores / 2));
  };
  usb = { config, ... }: {
    config = {
      usb.bus = if config.usb.useQemuXHCI
        then "usb3"
        else "usb-ehci1";
      pci.devices = let
        inherit (config.devices.usb3.settings) addr;
        masterbus = config.devices.usb-ehci1.settings.id;
      in if config.usb.useQemuXHCI then {
        usb3.settings = {
          driver = "qemu-xhci";
          p3 = 8;
          p2 = 16;
        };
      } else {
        usb-ehci1.settings = {
          driver = "ich9-usb-ehci1";
          addr = addr + ".0x7";
        };
        usb3.settings = {
          driver = "ich9-usb-uhci1";
          multifunction = true;
          masterbus = masterbus + ".0";
          firstport = 0;
        };
        usb-uhci2.settings = {
          driver = "ich9-usb-uhci2";
          masterbus = masterbus + ".0";
          firstport = 2;
          addr = addr + ".0x1";
        };
        usb-uhci3.settings = {
          driver = "ich9-usb-uhci3";
          masterbus = masterbus + ".0";
          firstport = 4;
          addr = addr + ".0x2";
        };
      };
    };
  };
in {
  imports = [ iothreads usb ];
  options = {
    usb.useQemuXHCI = mkEnableOption "qemu-xhci" // {
      default = true;
    };
    pci.devices = mkOption {
      type = with types; attrsOf (submodule ({ name, ... }: {
        config = mkIf (pciAddrs ? ${name}) {
          settings = mapAttrs (_: mkDefault) (removeAttrs pciAddrs.${name} [ "device" ]);
          device = pciAddrs.${name}.device or { };
        };
      }));
    };
  };
  config = {
    flags = {
      nodefaults = true;
      no-user-config = true;
    };
    args = {
      monitor = if config.systemd.enable then "none" else "stdio";
    };
    cli = {
      msg.settings.timestamp = true;
      overcommit.settings.mem-lock = false;
      rtc.settings = {
        base = "localtime";
        driftfix = "slew";
      };
    };
    qmp.enable = true;
    globals.kvm-pit.lost_tick_policy = "delay";
    pci.devices = let
      netdevs = mapAttrs (name: netdev: {
        device.cli.dependsOn = [ netdev.id ];
        settings = {
          id = "${name}-dev";
          driver = if config.virtio.enable then "virtio-net-pci" else "e1000-82545em";
          netdev = netdev.id;
        };
      }) config.netdevs;
    in mkMerge [ netdevs ];
  };
}
