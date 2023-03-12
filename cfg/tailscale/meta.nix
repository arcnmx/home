{ lib, config, ... }: with lib; let
  cfg = config.network.tailscale;
  target = config.deploy.targets.common;
  inherit (target) tf;
  tailscaleDeviceModule = { config, name, ... }: {
    options = {
      addresses = mkOption {
        type = with types; listOf str;
      };
      id = mkOption {
        type = types.str;
      };
      name = mkOption {
        type = types.str;
        default = name;
      };
      shortName = mkOption {
        type = types.str;
        default = head (splitString "." config.name);
      };
      user = mkOption {
        type = types.str;
      };
      tags = mkOption {
        type = with types; listOf str;
      };
      isPersonalDevice = mkOption {
        type = types.bool;
        default = elem config.user cfg.users || config.shortName == "tewi";
      };
    };
  };
  mapRecord = addrIndex: dev: let
    address = elemAt dev.addresses addrIndex;
  in nameValuePair "${dev.shortName}.${cfg.domain}.${cfg.zone}-${toString addrIndex}" {
    inherit (cfg) zone;
    domain = "${dev.shortName}.${cfg.domain}";
    ${if hasInfix ":" address then "aaaa" else "a"} = {
      inherit address;
    };
  };
  ourDevices = filterAttrs (_: dev: dev.isPersonalDevice) cfg.devices;
  records = concatLists (mapAttrsToList (_: dev: imap0 (i: _: mapRecord i dev) dev.addresses) ourDevices);
in {
  options = {
    network.tailscale = {
      zone = mkOption {
        type = with types; nullOr str;
        default = null;
      };
      domain = mkOption {
        type = types.str;
      };
      devices = mkOption {
        type = with types; attrsOf (submodule tailscaleDeviceModule);
        default = { };
      };
      users = mkOption {
        type = with types; listOf str;
        default = [ ];
      };
    };
  };
  config = {
    network.tailscale.devices = optionalAttrs tf.state.enable (mapListToAttrs
      (dev: nameValuePair dev.name dev)
      tf.outputs.tailnet.import
    );
    deploy.targets = {
      common.tf = {
        resources = {
          tailnet = {
            provider = "tailscale";
            type = "devices";
            dataSource = true;
          };
        };
        outputs.tailnet = {
          sensitive = true;
          value = tf.resources.tailnet.refAttr "devices";
        };
      };
      archive.tf = {
        dns.records = mkIf (cfg.zone != null) (listToAttrs records);
      };
    };
  };
}
