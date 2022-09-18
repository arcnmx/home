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
        default = removeSuffix ("." + replaceStrings [ "@" ] [ "." ] config.user) config.name;
      };
      user = mkOption {
        type = types.str;
      };
      tags = mkOption {
        type = with types; listOf str;
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
  ourDevices = filterAttrs (_: dev: elem dev.user cfg.users) cfg.devices;
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
    network.tailscale.devices = mapListToAttrs (dev: nameValuePair dev.name dev) (tf.resources.tailnet.importAttr "devices");
    deploy.targets = {
      common.tf = {
        resources = {
          tailnet = {
            provider = "tailscale";
            type = "devices";
            dataSource = true;
          };
          tailnet-null = {
            provider = "null";
            type = "resource";
            inputs.triggers = {
              tailnet = tf.lib.tf.terraformExpr "sha256(jsonencode(${tf.resources.tailnet.namedRef}.devices))";
            };
          };
        };
      };
      archive.tf = {
        dns.records = mkIf (cfg.zone != null) (listToAttrs records);
      };
    };
  };
}
