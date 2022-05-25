{ modulesPath, pkgs, lib, config, ... }: with lib; {
  disabledModules = [
    # h-m pulls in a 200MB package unconditionally..?
    "config/i18n.nix"
    (/. + "${modulesPath}/modules/config/i18n.nix")
  ];

  config = {
    home.nix = {
      enable = true;
    };
    manual.manpages.enable = false;
    news.display = "silent";
  };
}
