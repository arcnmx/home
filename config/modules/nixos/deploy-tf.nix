{ target, meta, config, lib, ... }: with lib; let
  cfg = config.deploy.tf;
  unmergedValues = types.mkOptionType {
    name = "unmergedValues";
    merge = loc: defs: map (def: def.value) defs;
  };
in {
  options.deploy.tf = mkOption {
    type = types.submodule {
      freeformType = types.attrsOf unmergedValues;

      options = {
        import = mkOption {
          type = types.attrsOf types.unspecified;
          default = [ ];
        };
        imports = mkOption {
          type = types.listOf types.str;
          description = "Other targets to depend on";
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

  config = {
    secrets.external = true;
    deploy.tf = {
      attrs = [ "import" "imports" "out" "attrs" ];
      import = genAttrs cfg.imports (target: meta.deploy.targets.${target}.tf);
      out.set = removeAttrs cfg cfg.attrs;
    };
    _module.args.tf = mapNullable (target: target.tf) target;
  };
}
