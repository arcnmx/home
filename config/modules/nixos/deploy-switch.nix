{ meta, name, pkgs, lib, config, ... }: with lib; let
  cfg = config.deploy;
in {
  options.deploy = {
    system = mkOption {
      type = types.unspecified;
      readOnly = true;
    };
    network = let
      networkType = kind: types.submodule ({ ... }: {
        options = {
          ipv4 = mkOption {
            type = types.nullOr types.str;
          };
          ipv6 = mkOption {
            type = types.nullOr types.str;
            default = null;
          };
        };
        config = {
          ipv4 = mkIf (kind == "wan") (mkOptionDefault null);
          ipv6 = mkIf (config.deploy.network.ipv6.prefix.${kind} != null)
            (mkDefault "${config.deploy.network.ipv6.prefix.${kind}}:${config.deploy.network.ipv6.postfix.${kind}}");
        };
      });
    in {
      ipv6 = {
        postfix = {
          local = mkOption {
            type = types.str;
          };
          wan = mkOption {
            type = types.str;
            description = "SLAAC";
            default = config.deploy.network.ipv6.postfix.local;
          };
        };
        prefix = {
          local = mkOption {
            type = types.nullOr types.str;
            default = null;
          };
          wan = mkOption {
            type = types.nullOr types.str;
            default = null;
          };
        };
      };
      local = mkOption {
        type = networkType "local";
        default = { };
      };
      wan = mkOption {
        type = networkType "wan";
        default = { };
      };
    };
    targetName = mkOption {
      type = types.nullOr types.str;
      default = null;
    };
    local = {
      isRemote = mkOption {
        type = types.bool;
        default = config.networking.hostName != meta.deploy.local.hostName;
      };
    };
  };
  config = {
    deploy = {
      system = config.system.build.toplevel;
      targetName = mkIf (meta.deploy.targets ? ${name}) (mkDefault name);
      tf.deploy = {
        isRoot = meta.deploy.local.isRoot;
        systems.${name} = {
          nixosConfig = config;
          isRemote = cfg.local.isRemote;
          connection = {
            host = mkDefault config.networking.hostName;
          };
        };
      };
    };
    _module.args.target = mapNullable (targetName: meta.deploy.targets.${targetName}) cfg.targetName;
  };
}
