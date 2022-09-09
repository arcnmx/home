{ lib, nixosConfig, config, name, ... }: with lib; {
  options = {
    enable = mkEnableOption "enable";
    name = mkOption {
      type = types.str;
      default = name;
    };
    uuid = mkOption {
      type = with types; nullOr str;
      default = null;
    };
    debug = {
      enable = mkEnableOption "debugcon";
      path = mkOption {
        type = types.path;
      };
    };
    state = {
      owner = mkOption {
        type = types.str;
        default = "arc";
      };
      path = mkOption {
        type = types.path;
        default = "/var/lib/vfio/${config.name}";
      };
      runtimePath = mkOption {
        type = types.path;
        default = "/run/vfio/${config.name}";
      };
    };
    virtio = {
      enable = mkEnableOption "VIRTIO";
    };
  };
  config = {
    args = {
      uuid = mkIf (config.uuid != null) config.uuid;
      debugcon = mkIf config.debug.enable "file:${config.debug.path}";
    };
    cli = {
      name.settings = {
        guest = config.name;
        debug-threads = true;
      };
    };
    exec.preExec = mkBefore ''
      mkdir -p ${config.state.path}
      mkdir -p ${config.state.runtimePath}
    '';
  };
}
