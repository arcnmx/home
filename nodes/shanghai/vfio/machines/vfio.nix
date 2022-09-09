{ config, lib, ... }: with lib; let
  cfg = config.vfio;
in {
  options.vfio = {
    gpu = mkOption {
      type = with types; nullOr str;
      default = null;
    };
  };
  config = mkMerge [
    {
      args.vga = mkIf (cfg.gpu == null) "qxl";
    }
    (mkIf (cfg.gpu != null) {
      pci.devices.gpu.settings.multifunction = true;
      vfio.devices = {
        gpu = {
          name = cfg.gpu;
        };
        gpu-audio = {
          name = "${cfg.gpu}-audio";
        };
      };
    })
  ];
}
