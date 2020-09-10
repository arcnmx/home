{ pkgs, lib, config, ... }: let
  channels = import ./channels.nix { };
in with lib; {
  disabledModules = [
    (/. + "${toString channels.paths.home-manager}/modules/services/mpd.nix")
    (/. + "${toString channels.paths.home-manager}/modules/programs/git.nix")
    (/. + "${toString channels.paths.home-manager}/modules/programs/vim.nix")
    (/. + "${toString channels.paths.home-manager}/modules/programs/firefox.nix")
  ];

  imports = [
    modules/home
    profiles/home.nix
    "${toString channels.paths.arc}/modules/home"
  ];

  config = {
    home.nix = {
      enable = true;
      nixPath = mapAttrs (_: path: { path = toString path; }) channels.imports;
    };
    xdg.configFile = {
      "nixpkgs/config.nix".source = "${./channels}/nixpkgs.nix";
    };
    manual.manpages.enable = false;
    news.display = "silent";
    systemd.user.startServices = true;

    home.profiles = {
      base = mkDefault true;
    };

    _module.args = mkIf (config.home.nixosConfig == null) {
      pkgs = mkForce channels.nixpkgs;
      pkgs_i686 = mkForce null;
      nodes = { };
    };
  };
}
