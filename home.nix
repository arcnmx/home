let
  network = "gensokyo"; # TODO: supply this somehow, env var maybe
  inherit (import ./import.nix) pkgs;
  inherit (pkgs) lib;
  nodes = (import ./network.nix { inherit pkgs network; }).nodes;
  hosts = builtins.readDir ./config/profiles/host;
  base = {
    imports = [./config/home.nix];

    home.profiles.base = lib.mkDefault true;
    _module.args = {
      inherit nodes;
    };
  };
  hostConfigs = lib.mapAttrs (host: _: {
    imports = [base];
    config.home.hostName = host;
  }) hosts;
in hostConfigs // rec {
  inherit base;

  personal = {
    imports = [base];
    home.profiles.personal = true;
  };

  desktop = {
    imports = [personal];
    home.profiles.gui = true;
  };

  laptop = {
    imports = [personal];
    home.profiles.gui = true;
    home.profiles.laptop = true;
  };
}
