{ config, pkgs, lib, ... }: with lib; let
  cfg = config.deploy;
  meta = config;
  tfModule = { lib, ... }: with lib; {
    config._module.args = {
      pkgs = mkDefault pkgs;
    };
  };
  tfType = types.submoduleWith {
    modules = [
      tfModule
      "${toString config.channels.paths.tf}/modules"
    ];
  };
in {
  options = {
    deploy = {
      dataDir = mkOption {
        type = types.path;
      };
      local = {
        isRoot = mkOption {
          type = types.bool;
          default = builtins.getEnv "HOME_UID" == "0";
        };
        hostName = mkOption {
          type = types.nullOr types.str;
          default = let
            hostName = builtins.getEnv "HOME_HOSTNAME";
          in if hostName == "" then null else hostName;
        };
      };
      targets = let
        type = types.submodule ({ config, name, ... }: {
          options = {
            name = mkOption {
              type = types.str;
              default = name;
            };
            nodeNames = mkOption {
              type = types.listOf types.str;
              default = [ ];
            };
            tf = mkOption {
              type = tfType;
              default = { };
            };
          };
          config.tf = mkMerge (singleton {
            terraform = {
              #version = "0.13"; # TODO: this doesn't seem to be working right now? https://github.com/NixOS/nixpkgs/issues/98652
              logPath = cfg.dataDir + "/terraform-${config.name}.log";
              dataDir = cfg.dataDir + "/tfdata";
            };
            state = {
              file = cfg.dataDir + "/${config.name}.tfstate";
            };
            deps = {
              enable = true;
              apply.continue.run = {
                nixFilePath = ../../..;
                nixAttr = "deploy.targets.${name}.tf.runners.run.apply.package";
                nixArgs = [ "--show-trace" ];
              };
            };
            continue.envVar = "TF_NIX_CONTINUE_${config.name}";
          } ++ map (nodeName: mapAttrs (_: mkMerge) meta.network.nodes.${nodeName}.deploy.tf.out.set) config.nodeNames);
        });
      in mkOption {
        type = types.attrsOf type;
        default = { };
      };
    };
  };
}
