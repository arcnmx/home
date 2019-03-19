{ lib, config, ... }: with lib; {
  imports = (import ./modules.nix { }).nixosImports;

  config.home = {
    nixosConfig = config;
  };
}
