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
    share = mkOption {
      type = types.bool;
      default = false;
    };
    object = mkOption {
      type = with types; nullOr str;
      default = if cfg.share then "mem" else null;
    };
  };
  config = let
    devhp = "/dev/hugepages" + optionalString (cfg.prealloc == "1G") "1G";
    alloc-hugepages = "${nixosConfig.lib.arc-vfio.alloc-hugepages}/bin/alloc-hugepages";
    alloc2m = if cfg.prealloc == "2M" then (cfg.sizeMB + 1) / 2 else 0;
    alloc1g = if cfg.prealloc == "1G" then (cfg.sizeMB + 1023) / 1024 else 0;
  in mkMerge [
    (mkIf (cfg.object == null) {
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
    })
    (mkIf (cfg.object != null) {
      objects.${cfg.object} = {
        settings = {
          backend = if cfg.prealloc == null
            then "memory-backend-memfd"
            else "memory-backend-file";
          prealloc = mkIf (cfg.prealloc != false) true;
          mem-path = mkIf (cfg.prealloc != false)
            "${devhp}/qemu-${config.name}";
          size = mkIf (cfg.sizeMB != null) cfg.sizeMB;
          inherit (cfg) share;
        };
      };
    })
    {
      exec.scriptText = mkIf (cfg.prealloc != false) (mkBefore ''
        ${alloc-hugepages} ${toString alloc2m} ${toString alloc1g}
      '');
    }
  ];
}
