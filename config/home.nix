{ pkgs, lib, nixosConfig, config, ... }: with lib; {
  options.home.profiles.trusted = mkEnableOption "trusted" // {
    default = nixosConfig.home.profiles.trusted;
  };
  config = {
    home.nix = {
      nixPath.cwd = "${../channels/cwd.nix}";
    };
    xdg.configFile = {
      "nixpkgs/config.nix".source = "${./channels}/nixpkgs.nix";
    };

    secrets.external = true;
  };
}
