{ lib, config, pkgs, ... }: with lib; let
  cfg = config.hardware.vfio;
in {
  config = {
    home.profileSettings.nvidia.dynamicBinding = true;
    hardware.vfio = {
      devices = {
        gtx3080 = {
          enable = true;
          vendor = "10de";
          product = "2206";
          host = "0c:00.0";
        };
        gtx3080-audio = {
          enable = true;
          vendor = "10de";
          product = "1aef";
          host = "0c:00.1";
          systemd.unit = rec {
            wantedBy = [ cfg.devices.gtx3080.systemd.id ];
            bindsTo = wantedBy;
          };
        };
        gtx1650 = {
          vendor = "10de";
          product = "1f82";
          host = "05:00.0";
          unbindVts = true;
          systemd.unit.conflicts = [ "graphical.target" "bind1650.service" ];
        };
        gtx1650-audio = {
          vendor = "10de";
          product = "10fa";
          host = "05:00.1";
          systemd.unit = rec {
            wantedBy = [ cfg.devices.gtx1650.systemd.id ];
            bindsTo = wantedBy;
          };
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
        arctis7p-plus = {
          vendor = "1038";
          product = "2212";
        };
        yubikey5-kat = {
          vendor = "1050";
          product = "0407";
          udev.conditions = [ ''ATTR{bcdDevice}=="0526"'' ];
        };
        yubikey5c-kat = {
          vendor = "1050";
          product = "0407";
          udev.conditions = [ ''ATTR{bcdDevice}=="0543"'' ];
        };
      };
      disks = {
        mapped = {
          windows-games = {
            source = "/dev/disk/by-partlabel/windows-games";
            mbr.id = "f4901f82";
            permission.owner = "arc";
          };
          windows-games-sabrent = {
            source = "/dev/disk/by-partlabel/windows-games-sabrent";
            mbr.id = "954e3dd3";
            permission.owner = "arc";
          };
          windows-games-bpx = {
            source = "/dev/disk/by-partlabel/windows-games-bpx";
            mbr.id = "3fa0fceb";
            permission.owner = "arc";
          };
          windows-games-adata = {
            source = "/dev/disk/by-partlabel/windows-games-adata";
            mbr.id = "58ec08ca";
          };
        };
        cow = {
          windows-games-adata-arc = {
            source = cfg.disks.mapped.windows-games-adata.path;
            storage = "/mnt/data/hourai/adata-snapshot-overlay";
            mode = "P";
            sizeMB = 1024 * 16;
            systemd.depends = [
              cfg.disks.mapped.windows-games-adata.systemd.id
            ];
            permission.owner = "arc";
          };
          windows-games-adata-kat = {
            source = cfg.disks.mapped.windows-games-adata.path;
            systemd.depends = [
              cfg.disks.mapped.windows-games-adata.systemd.id
            ];
            permission.owner = "kat";
          };
        };
      };
    };
    systemd.services = {
      bind1650 = rec {
        wantedBy = [ "display-manager.service" ];
        before = wantedBy;
        bindsTo = wantedBy;
        script = ''
          echo 0000:05:00.0 > /sys/bus/pci/drivers/nvidia/bind
        '';
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
      };
      windows-games-adata-arc = rec {
        requires = [ cfg.disks.mapped.windows-games-adata.systemd.id ];
        after = requires;
        conflicts = [
          cfg.disks.cow.windows-games-adata-arc.systemd.id
          cfg.disks.cow.windows-games-adata-kat.systemd.id
        ];
        unitConfig = {
          ConditionPathExists = "!${cfg.disks.cow.windows-games-adata-arc.storage}";
        };
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = [
            "${pkgs.coreutils}/bin/ln -s ${cfg.disks.mapped.windows-games-adata.path} /dev/disk/windows-games-adata-arc"
            "${pkgs.coreutils}/bin/chown arc ${cfg.disks.mapped.windows-games-adata.path}"
          ];
          ExecStop = [
            "${pkgs.coreutils}/bin/rm -f /dev/disk/windows-games-adata-arc"
            "${pkgs.coreutils}/bin/chown root ${cfg.disks.mapped.windows-games-adata.path}"
          ];
        };
      };
    };
    security.polkit.users = {
      kat.systemd.units = [ "graphical.target" ];
    };
    services.udev.extraRules = ''
      # my VM disks
      SUBSYSTEM=="block", ACTION=="add", ATTRS{model}=="INTEL SSDSC2BP48", ATTRS{wwid}=="naa.55cd2e404b6f84e5", OWNER="arc"
      SUBSYSTEM=="block", ACTION=="add", ATTR{partition}=="4", ATTR{size}=="125829120", ATTRS{wwid}=="eui.6479a741e0203d76", OWNER="arc"
      SUBSYSTEM=="block", ACTION=="add", ATTR{partition}=="6", ATTR{size}=="134217728", ATTRS{wwid}=="eui.002303563000ad1b", OWNER="arc"
      SUBSYSTEM=="block", ACTION=="add", ATTR{partition}=="6", ATTR{size}=="838860800", ATTRS{wwid}=="nvme.1cc1-324a34303230303035353234-414441544120535838323030504e50-00000001", OWNER="kat"
      SUBSYSTEM=="usb", ATTR{idVendor}=="1038", ATTR{idProduct}=="2212", GROUP="plugdev"
    '';
  };
}
