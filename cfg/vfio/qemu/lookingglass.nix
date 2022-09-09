{ config, lib, ... }: with lib; let
  cfg = config.lookingGlass;
in {
  options.lookingGlass = {
    enable = mkEnableOption "LookingGlass";
    sizeMB = mkOption {
      type = types.int;
      default = 64;
    };
    kvmfrIndex = mkOption {
      type = with types; nullOr int;
      default = null;
      example = 0;
    };
    path = mkOption {
      type = types.path;
      default = if cfg.kvmfrIndex != null then "/dev/kvmfr${cfg.kvmfrIndex}" else config.state.runtimePath + "/looking-glass";
    };
  };
  config = mkIf cfg.enable {
    ivshmem.devices.lookingGlass = mapAttrs (_: mkOptionDefault) {
      inherit (cfg) sizeMB path;
    };
  };
}
