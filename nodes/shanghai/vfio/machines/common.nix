{ nixosConfig, config, lib, ... }: with lib; let
  pciAddrs = rec {
    hostnet0 = "0x2";
    sound0 = "0x3";
    scsi0 = "0x4";
    usb3 = "0x5";
    lookingGlass = "0x6";
    scream = "0x7";
    gpu = "0x8";
    gpu-audio = gpu + ".0x1";
    balloon0 = "0x9";
    rng0 = "0xa";
    smbnet0 = "0xb";
    vserial0 = "0xc";
    natnet0 = "0xd";
    bridge = "0xe";
  };
  iothreads = { config, ... }: {
    config.objects = listToAttrs (genList (i: nameValuePair "io${toString i}" {
      settings.typename = "iothread";
    }) (nixosConfig.hardware.cpu.info.cores / 2));
  };
  usb = { config, ... }: {
    config = {
      usb.bus = "usb3";
      pci.devices = {
        usb3.settings = {
          driver = "qemu-xhci";
          p3 = 8;
          p2 = 8;
        };
      };
    };
  };
in {
  imports = [ iothreads usb ];
  options = {
    pci.devices = mkOption {
      type = with types; attrsOf (submodule ({ config, name, ... }: {
        config = mkIf (pciAddrs ? ${name}) {
          settings.addr = mkOptionDefault pciAddrs.${name};
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
    globals.kvm-pit.lost_tick_policy = "delay";
    pci.devices = let
      netdevs = mapAttrs (name: netdev: {
        settings = {
          id = "${name}-dev";
          driver = if config.virtio.enable then "virtio-net-pci" else "e1000-82545em";
          netdev = netdev.id;
        };
      }) config.netdevs;
    in mkMerge [ netdevs ];
  };
}
