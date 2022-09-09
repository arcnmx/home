{ config, lib, ... }: with lib; {
  config = {
    qga = {
      enable = mkDefault true;
      bus = config.devices.vserial0.id;
    };
    spice = {
      enable = mkDefault true;
      bus = config.devices.vserial0.id;
    };
    objects.rng0.settings = {
      typename = "rng-random";
      id = "rng0-random";
      filename = "/dev/random";
    };
    pci.devices = {
      balloon0.settings.driver = "virtio-balloon-pci";
      rng0 = {
        device.cli.dependsOn = [ config.objects.rng0.id ];
        settings = {
          driver = "virtio-rng-pci";
          rng = config.objects.rng0.id;
        };
      };
      scsi0 = {
        device.cli.dependsOn = [ config.objects.io0.id ];
        settings = {
          driver = "virtio-scsi-pci";
          iothread = config.objects.io0.id;
        };
      };
      vserial0.settings.driver = "virtio-serial";
    };
  };
}
