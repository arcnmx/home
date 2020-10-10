{ pkgs, lib, config, ... }: with lib; {
  imports = [
    profiles/home.nix
  ];

  config = {
    home.nix = {
      enable = true;
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
    secrets.external = true;
  };
}
