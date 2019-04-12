{ pkgs, lib, config, ... }: let
  channels = import ./channels.nix { };
in with lib; {
  disabledModules = [
    (/. + "${toString channels.paths.home-manager}/modules/programs/git.nix")
  ];

  imports = [
    modules/home
    profiles/home.nix
    "${toString channels.paths.arc}/modules/home"
  ];

  config = {
    xdg.configFile = {
      "nixpkgs/config.nix".source = "${./channels}/nixpkgs.nix";
    };

    home.profiles = {
      base = mkDefault true;
    };

    _module.args = mkIf (config.home.nixosConfig == null) {
      pkgs = mkForce channels.nixpkgs;
      nodes = { };
    };
  };
}
