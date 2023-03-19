{ lib, config, pkgs, ... }: with lib; let
  cfg = config.hardware.vfio;
  inherit (cfg.qemu) machines;
in {
  options.hardware.vfio = with types; {
    windowsGames = mkOption {
      type = attrsOf attrs;
      default = { };
      example = {
        sn770.scsi.lun = 6;
      };
    };
  };
  config = {
    home-manager.users.arc.home.scratch.linkDirs = [
      ".cache/vfio/cow"
    ];
    hardware.nvidia.dynamicBinding = true;
    hardware.vfio = {
      devices = {
        rtx3080 = {
          #enable = true;
          #reserve = true;
          driver = "nvidia";
          vendor = "10de";
          product = "2206";
          host = "0000:0d:00.0";
          gpu.nvidia = {
            uuid = "GPU-7df1e623-0847-6282-d1c2-7f7bb3ba99fc";
            settings = {
              power-limit = 250; # watts
              lock-gpu-clocks = [ 0 1630 ]; # range
            };
          };
        };
        rtx3080-audio = {
          #enable = true;
          reserve = true;
          vendor = "10de";
          product = "1aef";
          host = "0000:0d:00.1";
          vfio.unit = rec {
            wantedBy = [ cfg.devices.rtx3080.vfio.id ];
            bindsTo = wantedBy;
          };
        };
        gtx1650 = {
          unbindVts = true;
          driver = "nvidia";
          vendor = "10de";
          product = "1f82";
          host = "0000:06:00.0";
          gpu = {
            primary = true;
            nvidia = {
              uuid = "GPU-3ddd6066-bf5e-cdaa-ece5-3a753fd322f3";
            };
          };
        };
        gtx1650-audio = {
          vendor = "10de";
          product = "10fa";
          host = "0000:06:00.1";
          vfio.unit = rec {
            wantedBy = [ cfg.devices.gtx1650.vfio.id ];
            bindsTo = wantedBy;
            before = [ "display-manager.service" "nvidia-x11.service" ];
          };
        };
        hostusb-root = {
          vendor = "1022";
          product = "1485";
          host = "0000:11:00.0";
          vfio.unit = rec {
            wantedBy = [ cfg.devices.hostusb.vfio.id ];
            bindsTo = wantedBy;
          };
        };
        hostusb = {
          # CPU USB Controller
          enable = true;
          vendor = "1022";
          product = "149c";
          subvendor = "1458";
          subproduct = "5007";
          host = "0000:11:00.3";
        };
      };
      usb.devices = {
        svse5 = {
          vendor = "1d79";
          product = "0100";
        };
        hori = {
          vendor = "10f0";
          product = "0083";
        };
        xpad = {
          vendor = "045e";
          product = "0b12";
        };
        switch-pro = {
          vendor = "057e";
          product = "2009";
        };
        gmmk = {
          vendor = "0c45";
          product = "652f";
        };
        shift = {
          vendor = "04d8";
          product = "ee65";
        };
        nighthawk-x8 = {
          vendor = "0665";
          product = "6000";
        };
        ax200-bt = {
          vendor = "8087";
          product = "0029";
        };
        nagatrinity = {
          vendor = "1532";
          product = "0067";
        };
        naga2014 = {
          vendor = "1532";
          product = "0040";
        };
        oculus-sensor = {
          vendor = "2833";
          product = "0211";
        };
        oculus-audio = {
          vendor = "2833";
          product = "0330";
        };
        oculus-hub3 = {
          vendor = "2833";
          product = "3031";
        };
        oculus-hub2 = {
          vendor = "2833";
          product = "2031";
        };
        oculus-headset = {
          vendor = "2833";
          product = "0031";
        };
        arctis7p-plus = {
          vendor = "1038";
          product = "2212";
        };
        yubikey5 = {
          vendor = "1050";
          product = "0407";
          udev.rule = ''ATTR{bcdDevice}=="0526"'';
        };
        yubikey5c = {
          vendor = "1050";
          product = "0407";
          udev.rule = ''ATTR{bcdDevice}=="0543"'';
        };
      };
      windowsGames = {
      };
      disks = {
        mapped = {
          windows-games-sabrent = {
            source = "/dev/disk/by-partlabel/windows-games-sabrent";
            mbr.id = "415708fa";
            permission.owner = "arc";
          };
          windows-games-plextor = {
            source = "/dev/disk/by-partlabel/windows-games";
            mbr.id = "f4901f82";
            permission.owner = "arc";
          };
          windows-games-adata2 = {
            source = "/dev/disk/by-partlabel/windows-games-adata2";
            mbr.id = "954e3dd3";
            permission.owner = "arc";
          };
          windows-games-sn850x = {
            source = "/dev/disk/by-partlabel/windows-games-sn850x";
            mbr.id = "26ca4c08";
            permission.owner = "arc";
          };
          windows-games-adata = {
            source = "/dev/disk/by-partlabel/windows-games-adata";
            mbr.id = "58ec08ca";
            permission.owner = "arc";
          };
          windows-games-adata3 = {
            source = "/dev/disk/by-partlabel/windows-games-adata3";
            mbr.id = "dd8f10de";
            permission.owner = "arc";
          };
          game-storage = {
            systemd.enable = false;
            source = "/mnt/bigdata/vfio/disks/game-storage";
            mbr.id = "90a4fd21";
          };
        };
        cow = mkMerge (flip mapAttrsToList cfg.windowsGames (name: _: let
          windows-games = "windows-games-${name}";
          inherit (config.home-manager.users) arc;
        in {
          "${windows-games}-arc" = {
            source = cfg.disks.mapped.${windows-games}.path;
            storage = "${arc.xdg.cacheHome}/vfio/cow/${windows-games}-snapshot-overlay";
            mode = "P";
            sizeMB = 1024 * 16;
            systemd.depends = [
              cfg.disks.mapped.${windows-games}.systemd.id
            ];
            permission.owner = "arc";
          };
          "${windows-games}-kat" = {
            source = cfg.disks.mapped.${windows-games}.path;
            systemd = {
              inherit (machines.goliath1650) enable;
              depends = [
                cfg.disks.mapped.${windows-games}.systemd.id
              ];
            };
            permission.owner = "kat";
          };
        }));
      };
    };
    systemd.services = flip mapAttrs' cfg.windowsGames (name: _: let
      windows-games = "windows-games-${name}";
    in nameValuePair "vfio-mapdisk-${windows-games}-arc" rec {
      requires = [ cfg.disks.mapped.${windows-games}.systemd.id ];
      after = requires;
      conflicts = [
        cfg.disks.cow."${windows-games}-arc".systemd.id
        cfg.disks.cow."${windows-games}-kat".systemd.id
      ];
      unitConfig = {
        ConditionPathExists = "!${cfg.disks.cow."${windows-games}-arc".storage}";
      };
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = [
          "${pkgs.coreutils}/bin/ln -s ${cfg.disks.mapped.${windows-games}.path} /dev/disk/${windows-games}-arc"
          "${pkgs.coreutils}/bin/chown arc ${cfg.disks.mapped.${windows-games}.path}"
        ];
        ExecStop = [
          "${pkgs.coreutils}/bin/rm -f /dev/disk/${windows-games}-arc"
          "${pkgs.coreutils}/bin/chown root ${cfg.disks.mapped.${windows-games}.path}"
        ];
        TimeoutSec = 5;
      };
    });
    security.polkit.users = {
      kat.systemd.units = [ "graphical.target" ];
    };
    services.systemd2mqtt.units = [ "graphical.target" ];
    services.udev.extraRules = let
      adata = rec {
        attrs.wwid = "nvme.1cc1-324a34303230303035353234-414441544120535838323030504e50-00000001";
        windows-vm = {
          attr = {
            partition = 2;
            size = 125829120;
          };
          attrs = {
            inherit (attrs) wwid;
          };
        };
      };
      bx = rec {
        attrs = {
          wwid = "naa.55cd2e404b6f84e5";
          model = "INTEL SSDSC2BP48";
        };
      };
      blockadd = {
        attrs ? { }, attr ? { }
      , owner ? "arc"
      , actions ? [ ''OWNER="${owner}"'' ]
      , subsystem ? "block", action ? "add"
      , ...
      }: concatStringsSep ", " (
        [ ''SUBSYSTEM=="${subsystem}"'' ''ACTION=="${action}"'' ]
        ++ mapAttrsToList (name: value: ''ATTR{${name}}=="${toString value}"'') attr
        ++ mapAttrsToList (name: value: ''ATTRS{${name}}=="${toString value}"'') attrs
        ++ actions
      );
    in mkMerge (
      map blockadd [ bx adata.windows-vm ]
      ++ singleton ''SUBSYSTEM=="usb", ATTR{idVendor}=="1038", ATTR{idProduct}=="2212", GROUP="plugdev"''
    );
  };
}
