{ lib, config, pkgs, ... }: with lib; let
  cfg = config.hardware.vfio;
  windowsGames = [ "windows-games-adata" "windows-games-sn770" ];
in {
  config = {
    home.profileSettings.nvidia.dynamicBinding = true;
    hardware.vfio = {
      devices = {
        rtx3080 = {
          #enable = true;
          #reserve = true;
          vendor = "10de";
          product = "2206";
          host = "0000:0d:00.0";
        };
        rtx3080-audio = {
          #enable = true;
          reserve = true;
          vendor = "10de";
          product = "1aef";
          host = "0000:0d:00.1";
          systemd.unit = rec {
            wantedBy = [ cfg.devices.rtx3080.systemd.id ];
            bindsTo = wantedBy;
          };
        };
        gtx1650 = {
          vendor = "10de";
          product = "1f82";
          host = "0000:06:00.0";
          unbindVts = true;
          systemd.unit = {
            conflicts = [ "graphical.target" "nvidia-x11.service" ];
            after = [ "display-manager.service" ];
          };
        };
        gtx1650-audio = {
          vendor = "10de";
          product = "10fa";
          host = "0000:06:00.1";
          systemd.unit = rec {
            wantedBy = [ cfg.devices.gtx1650.systemd.id ];
            bindsTo = wantedBy;
            after = [ "display-manager.service" ];
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
          udev.rule = ''ATTR{bcdDevice}=="0526"'';
        };
        yubikey5c-kat = {
          vendor = "1050";
          product = "0407";
          udev.rule = ''ATTR{bcdDevice}=="0543"'';
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
          windows-games-sn850x = {
            source = "/dev/disk/by-partlabel/windows-games-sn850x";
            mbr.id = "26ca4c08";
            permission.owner = "arc";
          };
          windows-games-adata = {
            source = "/dev/disk/by-partlabel/windows-games-adata";
            mbr.id = "58ec08ca";
          };
          windows-games-sn770 = {
            source = "/dev/disk/by-partlabel/windows-games-sn770";
            mbr.id = "dd8f10de";
          };
        };
        cow = mkMerge (flip map windowsGames (windows-games: {
          "${windows-games}-arc" = {
            source = cfg.disks.mapped.${windows-games}.path;
            storage = "/mnt/data/hourai/${windows-games}-snapshot-overlay";
            mode = "P";
            sizeMB = 1024 * 16;
            systemd.depends = [
              cfg.disks.mapped.${windows-games}.systemd.id
            ];
            permission.owner = "arc";
          };
          "${windows-games}-kat" = {
            source = cfg.disks.mapped.${windows-games}.path;
            systemd.depends = [
              cfg.disks.mapped.${windows-games}.systemd.id
            ];
            permission.owner = "kat";
          };
        }));
      };
    };
    systemd.services = {
      nvidia-x11 = let
        gtx1650 = cfg.devices.gtx1650.host;
        rtx3080 = cfg.devices.rtx3080.host;
      in {
        path = [ config.systemd.package config.hardware.nvidia.package.bin ];
        script = mkMerge [
          (mkIf cfg.devices.rtx3080.reserve (mkAfter ''
            if [[ ! -L /sys/bus/pci/drivers/nvidia/${rtx3080} ]] && ! systemctl is-active ${cfg.devices.rtx3080.systemd.id}; then
              echo > /sys/bus/pci/devices/${rtx3080}/driver_override
              echo ${rtx3080} > /sys/bus/pci/drivers/nvidia/bind || true
            fi
          ''))
          (mkAfter ''
            if [[ -L /sys/bus/pci/drivers/nvidia/${rtx3080} ]]; then
              nvidia-smi drain -p ${rtx3080} -m 1 || true
            fi
            if [[ ! -L /sys/bus/pci/drivers/nvidia/${gtx1650} ]]; then
              echo > /sys/bus/pci/devices/${gtx1650}/driver_override
              echo ${gtx1650} > /sys/bus/pci/drivers/nvidia/bind
            fi
          '')
        ];
      };
    } // flip mapListToAttrs windowsGames (windows-games: nameValuePair "${windows-games}-arc" rec {
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
      };
    });
    security.polkit.users = {
      kat.systemd.units = [ "graphical.target" ];
    };
    services.systemd2mqtt.units = [ "graphical.target" ];
    services.udev.extraRules = ''
      # my VM disks
      SUBSYSTEM=="block", ACTION=="add", ATTRS{model}=="INTEL SSDSC2BP48", ATTRS{wwid}=="naa.55cd2e404b6f84e5", OWNER="arc"
      SUBSYSTEM=="block", ACTION=="add", ATTR{partition}=="4", ATTR{size}=="125829120", ATTRS{wwid}=="eui.6479a741e0203d76", OWNER="arc"
      SUBSYSTEM=="block", ACTION=="add", ATTR{partition}=="6", ATTR{size}=="134217728", ATTRS{wwid}=="eui.002303563000ad1b", OWNER="arc"
      SUBSYSTEM=="block", ACTION=="add", ATTR{partition}=="2", ATTR{size}=="838860800", ATTRS{wwid}=="eui.e8238fa6bf530001001b448b4bcd741f", OWNER="kat"
      SUBSYSTEM=="usb", ATTR{idVendor}=="1038", ATTR{idProduct}=="2212", GROUP="plugdev"
    '';
  };
}
