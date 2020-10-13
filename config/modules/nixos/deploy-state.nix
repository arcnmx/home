{ meta, config, lib, ... }: with lib; let
  config' = config;
  mutablePathType = super: types.submodule ({ config, ... }: {
    options = {
      name = mkOption {
        type = types.str;
        default = builtins.baseNameOf config.path;
      };

      path = mkOption {
        type = types.path;
      };

      owner = mkOption {
        type = types.str;
        default = super.owner;
      };
      group = mkOption {
        type = types.str;
        default = super.group;
      };

      exclude = mkOption {
        type = types.listOf types.str;
        default = [ ];
      };

      excludeExtract = mkOption {
        type = types.listOf types.str;
        default = [ ];
      };
    };
  });
  mutableStateType = types.submodule ({ config, name, ... }: {
    options = {
      enable = mkEnableOption "${name} mutable state" // {
        default = true;
      };
      instanced = mkOption {
        type = types.bool;
        default = false;
        description = "Set if the service may be deployed to multiple machines in a network";
      };
      backup = {
        frequency.days = mkOption {
          type = types.int;
          default = 3;
        };
      };
      name = mkOption {
        type = types.str;
        default = name;
      };
      # TODO: pre/post backup actions/commands...
      databases = {
        postgresql = mkOption {
          type = types.listOf types.str;
          default = [ ];
        };
      };
      owner = mkOption {
        type = types.str;
        default = "root";
      };
      group = mkOption {
        type = types.str;
        default = "root";
      };
      serviceNames = mkOption {
        type = types.listOf types.str;
        default = [ ];
      };
      paths = mkOption {
        type = types.listOf (types.coercedTo types.path (path: { inherit path; }) (mutablePathType config));
        default = [ ];
      };
    };
    config = {
      serviceNames = mkIf (config'.systemd.services ? ${name}) [ name ];
      owner = mkIf (config'.users ? ${name}) (mkDefault name);
      group = mkIf (config'.groups ? ${name}) (mkDefault name);
    };
  });
in {
  options.deploy.mutableState = mkOption {
    type = types.attrsOf mutableStateType;
    default = { };
  };
  config = {
    deploy.mutableState = {
      bitlbee = {
        enable = mkDefault config.services.bitlbee.enable;
        paths = [ config.services.bitlbee.configDir ];
      };
      prosody = {
        enable = mkDefault config.services.prosody.enable;
        databases.postgresql = mkIf (config.services.postgresql.enable) [ "prosody" ];
        paths = singleton config.services.prosody.dataDir;
      };
      matrix-synapse = {
        enable = mkDefault config.services.matrix-synapse.enable;
        databases.postgresql = mkIf (config.services.matrix-synapse.database_type == "psycopg2" && config.services.postgresql.enable) [ "matrix-synapse" ];
        paths = singleton config.services.matrix-synapse.dataDir;
      };
      bitwarden_rs = {
        enable = mkDefault config.services.bitwarden_rs.enable;
        databases.postgresql = mkIf (config.services.bitwarden_rs.dbBackend == "postgresql" && config.services.postgresql.enable) [ "bitwarden_rs" ];
        paths = singleton {
          path = config.services.bitwarden_rs.config.dataFolder; # TODO: module doesn't expose this anymore???
          exclude = [
            "icon_cache"
          ];
          excludeExtract = [
            "config.json"
          ];
        };
      };
      gitolite = {
        enable = mkDefault config.services.gitolite.enable;
        paths = singleton {
          path = config.services.gitolite.dataDir;
          excludeExtract = [
            ".gitolite.rc"
            ".gitolite"
            ".ssh"
          ];
        };
      };
      taskserver = {
        enable = mkDefault config.services.taskserver.enable;
        paths = singleton {
          path = config.services.taskserver.dataDir;
          owner = config.services.taskserver.user;
          group = config.services.taskserver.group;
          excludeExtract = [
            "config"
            "*.pem"
            "generate*"
            "vars"
          ];
        };
      };
    };
  };
}
