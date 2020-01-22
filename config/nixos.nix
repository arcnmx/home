{ pkgs, config, lib, nodes, modulesPath, ... }:
let
  channels = import ./channels.nix { inherit pkgs; };
  user = { lib, ... }: {
    imports = [./home.nix];

    nixpkgs = {
      inherit (config.nixpkgs) config overlays system;
    };
    home.nix.nixPath = lib.mapAttrs (_: path: lib.mkForce { path = toString path; }) channels.imports;
    _module.args = {
      inherit nodes;
      pkgs = lib.mkForce channels.pkgs;
      pkgs_i686 = lib.mkForce null;
    };

    home = {
      nixosConfig = config;

      profiles = config.home.profiles;
    };
  };
in {
  system.stateVersion = "19.09"; # this setting seems like a mess

  disabledModules = [
    (modulesPath + "/services/networking/connman.nix")
  ];

  imports = [
    "${toString channels.paths.home-manager}/nixos"
    "${toString channels.paths.arc}/modules/nixos"
    profiles/nixos.nix
    modules/nixos
  ];

  nix = {
    inherit (channels) nixPath;
    allowedUsers = ["@builders"];
    trustedUsers = ["root" "@wheel"];
    buildCores = 0;
    maxJobs = lib.mkDefault 6; # "auto"
  };

  nixpkgs = {
    inherit (channels.config.nixpkgs) config overlays;
  };

  home-manager.useUserPackages = true;
  home-manager.users = {
    arc = user;
    root = { lib, ... }: {
      imports = [user];

      config.home.profiles = with lib; {
        personal = mkForce false;
        gui = mkForce false;
        laptop = mkForce false;
      };
    };
  };

  documentation.nixos.enable = false;

  users.users = {
    root = {
      shell = pkgs.zsh;
    };
    arc = {
      isNormalUser = true;
      initialPassword = "hello";
      extraGroups = ["wheel" "builders" "kvm" "uinput"];
      shell = pkgs.zsh;
    };
  };
  programs.zsh.enable = true; # what does this do exactly?

  home.profiles = {
    base = lib.mkDefault true;
  };
}
