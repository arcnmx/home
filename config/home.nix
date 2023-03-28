{ pkgs, lib, nixosConfig, meta, config, ... }: with lib; let
  channels = ./channels;
in {
  config = {
    home.nix = {
      nixPath.cwd = "${channels}/cwd.nix";
    };
    xdg.configFile = {
      "nixpkgs/config.nix".source = "${channels}/nixpkgs.nix";
      "nixpkgs/overlays.nix".text = ''
        [
          (import ${channels}/overlay.nix)
        ]
      '';
    };

    secrets.external = true;
  };
}
