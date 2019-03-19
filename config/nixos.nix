{ pkgs, config, lib, nodes, ... }:
let
  channels = import ./channels.nix { inherit pkgs; };
  user = _: {
    imports = [./home.nix];

    nixpkgs = {
      inherit (config.nixpkgs) config overlays system;
    };
    _module.args = {
      inherit nodes;
      pkgs = lib.mkForce pkgs;
    };

    home = {
      nixosConfig = config;

      profiles = config.home.profiles;
    };
  };
in {
  system.stateVersion = "19.09"; # this setting seems like a mess

  imports = [
    /*<home-manager/nixos>*/ "${toString channels.paths.home-manager}/nixos"
    /*<arc/modules/nixos>*/ "${toString channels.paths.arc}/modules/nixos"
    profiles/nixos.nix
  ];

  nix = {
    inherit (channels) nixPath;
    allowedUsers = ["@builders"];
    trustedUsers = ["root" "@wheel"];
    buildCores = 0;
    #maxJobs = "auto"; # https://github.com/NixOS/nixpkgs/issues/50623
    maxJobs = lib.mkDefault 6;
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
