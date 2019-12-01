{ }: let
  hasTrusted = builtins.pathExists ./trusted/home.nix;
  importNames = [
    ./base
    ./gui
    ./personal
    ./trusted
    ./vfio
    ./laptop
    hw/intel
    hw/ryzen
    hw/nvidia
    hw/x370gpc
    hw/xps13
    host/gensokyo
    host/satorin
    host/shanghai
    host/flandre
  ];
  homeImports = (builtins.filter builtins.pathExists
    (map (name: name + "/home.nix") importNames)) ++ sharedImports;
  nixosImports = (builtins.filter builtins.pathExists
    (map (name: name + "/nixos.nix") importNames)) ++ sharedImports;
  sharedImports = [({ nodes, lib, config, options, ... }: with lib; {
    options.home = {
      hostName = mkOption {
        type = types.nullOr types.str;
        default = null;
      };

      nixosConfig = mkOption {
        type = types.nullOr types.unspecified;
        default = null;
      };

      nixosHome = mkOption {
        type = types.nullOr types.unspecified;
        default = null;
      };

      profiles.${if !hasTrusted then "trusted" else null} = mkEnableOption "trusted profile unavailable";
    };

    # TODO: proper submodules for this and put it into arc/modules
    options.network = {
      yggdrasil = mkOption {
        type = types.attrs;
        default = { };
      };
      wan = mkOption {
        type = types.attrs;
        default = { };
      };
    };

    config.network.yggdrasil = lib.mapAttrs (name: node: {
      address = node.services.yggdrasil.address;
    }) nodes;

    config.network.wan = lib.mapAttrs (name: node: {
      address = "${node.networking.hostName}.${node.networking.domain}";
    }) nodes;

    config.home = {
      hostName = (mkMerge [
        (mkIf (config ? home.nixosConfig.networking.hostName) (mkDefault config.home.nixosConfig.networking.hostName))
        (mkIf (config ? home.nixosHome.hostName) (mkOverride 999 config.home.nixosHome.hostName))
      ]);
      profiles.host = lib.optionalAttrs (config.home.hostName != null && options ? home.profiles.host.${config.home.hostName}) {
        ${config.home.hostName} = true;
      };
      profiles.trusted = mkIf (!hasTrusted) (mkForce false);
    };
  })];
in {
  inherit homeImports nixosImports;
}
