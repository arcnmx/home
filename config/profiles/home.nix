{ lib, config, ... }: with lib; {
  imports = (import ./modules.nix { }).homeImports;

  config.home = {
    nixosHome = mkIf (config ? home.nixosConfig.home) config.home.nixosConfig.home;
  };
}
