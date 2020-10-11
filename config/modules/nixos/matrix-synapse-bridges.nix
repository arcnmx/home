{ config, pkgs, lib, ... }: with lib; let
  cfg = config.services.matrix-synapse.bridges;
  enabledBridges = filter (cfg: cfg.enable) (attrValues cfg);
  bridgeType = types.submodule ({ name, config, ... }: {
    options = {
      enable = mkOption {
        type = types.bool;
        default = false;
      };
      createUser = mkOption {
        type = types.bool;
        default = true;
      };
      user = mkOption {
        type = types.nullOr types.str;
        default = config.name;
      };
      group = mkOption {
        type = types.nullOr types.str;
        default = config.user;
      };
      dataDir = mkOption {
        type = types.path;
        default = "/var/lib/${config.name}";
      };
      name = mkOption {
        type = types.str;
        default = "matrix-appservice-${name}";
      };
      package = mkOption {
        type = types.nullOr types.package;
      };
      exec = mkOption {
        type = types.str;
        default = "${config.package}/bin/${config.name}";
      };
      port = mkOption {
        type = types.nullOr types.int;
        default = null;
      };
      cmdline = mkOption {
        type = types.str;
        default = "${config.exec} -c ${config.configPath} -f ${config.registrationPath}" +
          optionalString (config.port != null) " -p ${toString config.port}";
      };
      configPath = mkOption {
        type = types.path;
      };
      registrationPath = mkOption {
        type = types.path;
      };
    };
  });
in {
  options.services.matrix-synapse.bridges = mkOption {
    type = types.attrsOf bridgeType;
    default = { };
  };
  config = mkMerge [ {
    services.matrix-synapse = {
      app_service_config_files = map (cfg: cfg.registrationPath) enabledBridges;
      bridges = {
        hangouts = {
          name = "mautrix-hangouts";
          package = pkgs.mautrix-hangouts;
          cmdline = with cfg.hangouts;
            "${exec} -c ./config.yaml -b ${package}/lib/${pkgs.python3.libPrefix}/site-packages/mautrix_hangouts/example-config.yaml";
        };
        whatsapp = {
          name = "mautrix-whatsapp";
          package = pkgs.mautrix-whatsapp;
          cmdline = with cfg.whatsapp;
            "${exec} -c ${configPath}";
        };
        irc = {
          package = pkgs.matrix-appservice-irc;
        };
        discord = {
          package = pkgs.matrix-appservice-discord;
        };
        puppet-discord = {
          name = "mx-puppet-discord";
          package = pkgs.mx-puppet-discord;
          cmdline = with cfg.puppet-discord;
            "${exec} -c ${configPath} -f ${registrationPath}";
        };
      };
    };
  } (mkIf config.services.matrix-synapse.enable {
    systemd.services = (mkMerge (singleton {
      ${cfg.hangouts.name} = with cfg.hangouts; mkIf enable {
        preStart = ''
          install -m0600 ${configPath} ./config.yaml
          ln -Tsf ${package}/alembic ./alembic
          ${package.alembic}/bin/alembic \
            -x config=./config.yaml \
            -c ${package}/alembic.ini \
            upgrade head
        '';
      };
    } ++ singleton (listToAttrs (map (cfg: nameValuePair cfg.name {
      serviceConfig = {
        ExecStart = cfg.cmdline;
      } // optionalAttrs cfg.createUser {
        User = cfg.user;
        Group = cfg.group;
        WorkingDirectory = cfg.dataDir;
      };
      requisite = [ "matrix-synapse.service" ]; # TODO: this only really applies if the service is local...
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
    }) (filter (cfg: cfg.package != null) enabledBridges)))));
    # TODO: deploy.mutableState = mapListToAttrs (cfg: nameValuePair cfg.name { paths = cfg.dataDir; }) enabledBridges;
    users = let
      bridges = filter (cfg: cfg.createUser) enabledBridges;
    in {
      users = listToAttrs (map (cfg: nameValuePair cfg.user {
        home = cfg.dataDir;
        createHome = true;
        group = cfg.group;
      }) bridges);
      groups = listToAttrs (map (cfg: nameValuePair cfg.user {
        #members = [ cfg.user ];
      }) bridges);
    };
  }) ];
}
