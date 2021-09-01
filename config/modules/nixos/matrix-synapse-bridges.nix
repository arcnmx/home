{ tf, config, pkgs, lib, ... }: with lib; let
  sensitiveModule = { config, options, ... }: {
    options = {
      secret = {
        enable = mkEnableOption "secret file" // { default = config.hasSensitive; };
        name = mkOption {
          type = types.str;
          default = "${config.name}.${config.format}";
        };
        owner = mkOption {
          type = types.str;
        };
        group = mkOption {
          type = types.str;
          default = "root";
        };
      };
    };
    config = {
      hasSensitive = mkDefault options.sensitiveSettings.isDefined;
      sensitivePath = mkIf config.secret.enable nixosConfig.secrets.files.${config.secret.name}.path;
    };
  };
  registrationModule = { config, ... }: {
    options = {
      token.generate = mkEnableOption "generate tokens";
    };
    config = {
      token = mkIf config.token.generate {
        appservice = tf.resources."matrix-appservice-${config.id}-appservice".refAttr "result";
        homeserver = tf.resources."matrix-appservice-${config.id}-homeserver".refAttr "result";
      };
      configuration = { ... }: {
        imports = [ sensitiveModule ];
        config.hasSensitive = mkIf config.token.generate true;
      };
    };
  };
  appserviceModule = { config, options, ... }: {
    config = {
      registration = { ... }: {
        imports = [ registrationModule ];
        config = {
          token.generate = true;
          configuration.secret = {
            owner = mkDefault config.user;
            group = mkDefault config.group;
          };
        };
      };
    } // optionalAttrs (options ? configuration) {
      configuration = { ... }: {
        imports = [ sensitiveModule ];
        config.secret = {
          owner = mkDefault config.user;
          group = mkDefault config.group;
        };
      };
    };
  };
  synapseAppserviceModule = { config, ... }: {
    config = {
      configuration.secret = {
        owner = mkOptionDefault "matrix-synapse";
        group = mkDefault "matrix-synapse";
      };
    };
  };
  nixosConfig = config;
  enabledAppservices = filter (a: a.enable) (attrValues config.services.matrix-appservices);
  enabledSynapseAppservices = filter (a: a.enable) (attrValues config.services.matrix-synapse.appservices);
  enabledSensitive' =
    map (a: a.configuration) (filter (a: a ? configuration) enabledAppservices)
    ++ map (a: a.registration.configuration) enabledAppservices
    ++ map (a: a.configuration) (optionals config.services.matrix-synapse.enable enabledSynapseAppservices);
  enabledSensitive = filter (s: s.secret.enable) enabledSensitive';
in {
  options.services = {
    matrix-appservices = mkOption {
      type = with types; attrsOf (submodule appserviceModule);
    };
    matrix-synapse.appservices = mkOption {
      type = with types; attrsOf (submodule [ registrationModule synapseAppserviceModule ]);
    };
  };
  config = {
    deploy.tf.resources = mkMerge (map (appservice: let
      token = {
        provider = "random";
        type = "password";
        inputs = {
          length = 64;
          upper = false;
          lower = true;
          number = true;
          special = false;
        };
      };
    in {
      "matrix-appservice-${appservice.registration.id}-appservice" = token;
      "matrix-appservice-${appservice.registration.id}-homeserver" = token;
    }) (filter (a: a.registration.token.generate) enabledAppservices));
    secrets.files = listToAttrs (map (conf: nameValuePair conf.secret.name {
      text = builtins.toJSON conf.sensitiveSettings;
      inherit (conf.secret) owner group;
    }) enabledSensitive);
  };
}
