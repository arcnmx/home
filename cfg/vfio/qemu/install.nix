{ config, lib, ... }: with lib; let
  cfg = config.install;
in {
  options.install = {
    enable = mkEnableOption "installer";
    image = mkOption {
      type = types.path;
    };
    virtio = {
      enable = mkEnableOption "VIRTIO windows drivers" // {
        default = true;
      };
      image = mkOption {
        type = types.path;
        default = "${pkgs.fetchurl {
          src = "https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/archive-virtio/virtio-win-0.1.221-1/virtio-win-0.1.221.iso";
          sha256 = "196817297921be7b65d73dd2ad7fd9a7c825b455eaa218432f351c3300ecacf5";
        }}";
      };
    };
  };
  config = mkIf cfg.enable {
    disks = {
      install = {
        scsi = {
          driver = "scsi-cd";
          lun = null;
        };
        path = cfg.image;
      };
      virtio-drivers = mkIf cfg.virtio.enable {
        ide = {
          driver = "ide-cd";
          bus = config.pci.devices.ide-install.settings.id;
          slot = 0;
        };
        path = cfg.virtio.image;
      };
    };
    pci.devices.ide-install = {
      settings = {
        driver = "ich9-ahci";
        addr = null;
      };
    };
  };
}
