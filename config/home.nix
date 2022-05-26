{ pkgs, lib, nixosConfig, config, ... }: with lib; {
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
