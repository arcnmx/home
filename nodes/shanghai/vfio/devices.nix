{ lib, config, ... }: with lib; let
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
    };
    services.udev.extraRules = ''
      # my VM disks
      SUBSYSTEM=="block", ACTION=="add", ATTRS{model}=="INTEL SSDSC2BP48", ATTRS{wwid}=="naa.55cd2e404b6f84e5", OWNER="arc"
      SUBSYSTEM=="block", ACTION=="add", ATTR{partition}=="4", ATTR{size}=="125829120", ATTRS{wwid}=="eui.6479a741e0203d76", OWNER="arc"
      SUBSYSTEM=="block", ACTION=="add", ATTR{partition}=="6", ATTR{size}=="134217728", ATTRS{wwid}=="eui.002303563000ad1b", OWNER="arc"
    '';
  };
}
