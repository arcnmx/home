{ target, tf, meta, config, lib, ... }: with lib; let
  cfg = config.deploy.tf;
  inherit (config) deploy;
in {
  options.deploy.tf = mkOption {
    type = types.submodule {
      inherit (unmerged) freeformType;

      options = {
        import = mkOption {
          type = types.attrsOf types.unspecified;
          default = [ ];
        };
        attrs = mkOption {
          type = types.listOf types.str;
          default = [ ];
        };
        out.set = mkOption {
          type = types.unspecified;
        };
      };
    };
  };
  options.deploy.imports = mkOption {
    type = types.listOf types.str;
    description = "Other targets to depend on";
    default = [ ];
  };

  config = {
    secrets.external = true;
    deploy.tf = {
      attrs = [ "import" "out" "attrs" ];
      import = genAttrs deploy.imports (target: meta.deploy.targets.${target}.tf // {
        output = tf.resources."${target}_state" // {
          import = mapAttrs (_: output: output.import) meta.deploy.targets.${target}.tf.outputs;
        };
      });
      resources = mapListToAttrs (target: nameValuePair "${target}_state" {
        provider = "terraform";
        type = "remote_state";
        dataSource = true;
        inputs = {
          backend = "local";
          config.path = toString tf.import.${target}.state.file;
        };
      }) deploy.imports;
      out.set = removeAttrs cfg cfg.attrs;
    };
    _module.args.tf = mapNullable (target: target.tf // {
      inherit (config.deploy.tf) import;
    }) target;
    home-manager.extraSpecialArgs = {
      inherit tf;
    };
  };
}
