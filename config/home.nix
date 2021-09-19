{ meta, pkgs, lib, config, ... }: with lib; {
  imports = [
    profiles/home.nix
  ];

  disabledModules = [
    # h-m pulls in a 200MB package unconditionally..?
    "config/i18n.nix"
    (/. + "${toString meta.channels.paths.home-manager}/modules/config/i18n.nix")
  ];

  config = {
    home.nix = {
      enable = true;
      nixPath.cwd = "${../channels/cwd.nix}";
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
