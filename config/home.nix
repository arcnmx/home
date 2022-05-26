{ pkgs, lib, nixosConfig, meta, config, ... }: with lib; {
  config = {
    home.nix = {
      nixPath.cwd = "${./channels/cwd.nix}";
    };
    xdg.configFile = {
      "nixpkgs/config.nix".source = "${./channels}/nixpkgs.nix";
      "nixpkgs/overlays.nix".text = ''
        [
          ${concatMapStringsSep " " (p: "(import ${p}/overlay.nix)") meta.channels.overlays}
        ]
      '';
    };

    secrets.external = true;
  };
}
