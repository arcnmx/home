{ nixosConfig, config, lib, name, ... }: with lib; let
  cfg = config.memory;
in {
  options.memory = {
    sizeMB = mkOption {
      type = with types; nullOr int;
      default = null;
    };
    prealloc = mkOption {
      type = types.enum [ false "2M" "1G" ];
      default = false;
    };
  };
  config = let
    devhp = "/dev/hugepages" + optionalString (cfg.prealloc == "1G") "1G";
    alloc-hugepages = "${nixosConfig.lib.arc-vfio.alloc-hugepages}/bin/alloc-hugepages";
    alloc2m = if cfg.prealloc == "2M" then (cfg.sizeMB + 1) / 2 else 0;
    alloc1g = if cfg.prealloc == "1G" then (cfg.sizeMB + 1023) / 1024 else 0;
  in {
    flags = {
      mem-prealloc = mkIf (cfg.prealloc != false) true;
    };
    args = {
      mem-path = mkIf (cfg.prealloc != false)
        "${devhp}/qemu-${config.name}";
    };
    cli.m = mkIf (cfg.sizeMB != null) {
      settings.size = mkOptionDefault cfg.sizeMB;
    };
    exec.scriptText = mkIf (cfg.prealloc != false) (mkBefore ''
      ${alloc-hugepages} ${toString alloc2m} ${toString alloc1g}
    '');
  };
}
