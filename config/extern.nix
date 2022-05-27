{ tf, config, lib, ... }: with lib; let
  cfg = config.extern;
  nixosConfig = config;
  externEntry = { options, config, name, ... }: {
    options = {
      name = mkOption {
        type = types.str;
        default = name;
      };
      value = mkOption {
        type = types.unspecified;
        readOnly = true;
      };
      type = mkOption {
        type = types.str;
        readOnly = true;
      };
      asFile = mkOption {
        type = types.bool;
        default = false;
      };
      tf = {
        enable = mkOption {
          type = types.bool;
          default = options.tf.text.isDefined;
        };
        sensitive = mkOption {
          type = types.bool;
          default = false;
        };
        text = mkOption {
          type = types.str;
        };
      };
      bitw = {
        name = mkOption {
          type = types.nullOr types.str;
          default = null;
        };
      };
    };
    config = {
      type = if config.asFile then "secret"
        else if config.bitw.name != null then "variable"
        else throw "unknown extern ${name}";
      value = {
        secret = nixosConfig.secrets.files.${config.name}.path;
        variable = tf.variables.${config.name}.get;
      }.${config.type};
    };
  };
in {
  options.extern = {
    enable = mkEnableOption "extern" // {
      default = tf.state.enable;
    };
    entries = mkOption {
      type = types.attrsOf (types.submodule externEntry);
      default = { };
    };
  };

  config = {
    deploy.tf = {
      variables = mapAttrs' (_: e: nameValuePair e.name {
        export = true;
        bitw.name = e.bitw.name;
      }) (filterAttrs (_: e: e.type == "variable") cfg.entries);
    };

    secrets.files = mapAttrs' (_: e: nameValuePair e.name {
      text = e.tf.text;
    }) (filterAttrs (_: e: e.type == "secret") cfg.entries);

    _module.args.extern = {
      enable = cfg.enable;
      get = mapAttrs (_: e: e.value) cfg.entries;
      path = mapAttrs (_: e: e.value) cfg.entries;
    };
  };
}
