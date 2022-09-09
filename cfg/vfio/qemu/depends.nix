{ config, lib, inputs, ... }: with lib; let
  cfg = config.depends;
  dag = import (inputs.home-manager.outPath + "/modules/lib/dag.nix") {
    lib = lib // {
      hm = {
        inherit dag;
      };
    };
  };
  dagify = _: cli: (if cli.dependsOn == [] then dag.entryAnywhere else dag.entryAfter cli.dependsOn) null;
  dependsCliModule = { depends, name, config, ... }: {
    options = {
      dependsOn = mkOption {
        type = with types; listOf str;
        default = [ ];
      };
    };
    config.order = mkIf depends.enable depends.orderById.${name};
  };
in {
  options = {
    depends = {
      enable = mkEnableOption "dependency graph" // {
        default = true;
      };
      dag = mkOption {
        type = types.attrs;
      };
      sorted = mkOption {
        type = types.unspecified;
      };
      orderById = mkOption {
        type = types.attrs;
      };
    };
    cli = mkOption {
      type = types.attrsOf (types.submoduleWith {
        modules = [ dependsCliModule ];
        shorthandOnlyDefinesConfig = true;
        specialArgs.depends = cfg;
      });
    };
  };
  config.depends = {
    dag = mapAttrs dagify config.cli;
    sorted = dag.topoSort cfg.dag;
    orderById = listToAttrs (imap0 (i: cli: nameValuePair cli.name i) cfg.sorted.result);
  };
}
