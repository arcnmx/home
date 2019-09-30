let
  inherit (builtins.import ./import.nix) import;
  network = "gensokyo"; # TODO: supply this somehow, env var maybe
  inherit (import ./. { }) pkgs;
  inherit (pkgs) lib;
  nodes = (import ./network.nix { inherit pkgs; }).${network}.nodes;
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
  home-manager-path = (import ./. { }).paths.home-manager + "/home-manager/home-manager.nix";
  configs = hostConfigs // rec {
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
  };
in configs // {
  home = builtins.mapAttrs (confAttr: _: (import home-manager-path {
    confPath = ./home.nix;
    inherit confAttr;
  }).activationPackage) configs;
}
