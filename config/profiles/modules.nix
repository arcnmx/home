{ }: let
  hasTrusted = builtins.pathExists ./trusted/home.nix;
  importNames = [
    ./base
    ./gui
    ./personal
    ./trusted
    ./vfio
    ./laptop
    hw/cross
    hw/intel
    hw/ryzen
    hw/nvidia
    hw/x370gpc
    hw/x570am
    hw/xps13
    hw/pinecube
    host/gensokyo
    host/satorin
    host/shanghai
    host/flandre
    host/mystia
    host/cirno
    host/aya
  ];
  homeImports = (builtins.filter builtins.pathExists
    (map (name: name + "/home.nix") importNames)) ++ sharedImports;
  nixosImports = (builtins.filter builtins.pathExists
    (map (name: name + "/nixos.nix") importNames)) ++ sharedImports;
  metaImports = (builtins.filter builtins.pathExists
    (map (name: name + "/meta.nix") importNames));
  sharedImports = [({ lib, config, options, ... }: with lib; {
    options.home = {
      profiles.${if !hasTrusted then "trusted" else null} = mkEnableOption "trusted profile unavailable";
    };

    config.home = {
      profiles.host = lib.optionalAttrs (config.home.hostName != null && options ? home.profiles.host.${config.home.hostName}) {
        ${config.home.hostName} = true;
      };
      profiles.trusted = mkIf (!hasTrusted) (mkForce false);
    };
  })];
in {
  inherit homeImports nixosImports metaImports;
}
