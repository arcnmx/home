{ pkgs, config, lib, nodes, modulesPath, ... }:
let
  nixosConfig = config;
  user = { config, ... }: {
    imports = nixosConfig.home.extraModules ++ [
      ./home.nix
    ];

    home = {
      profiles = config.home.nixosConfig.home.profiles;
    };
  };
in {
  system.stateVersion = lib.mkDefault "21.11";

  imports = [
    profiles/nixos.nix
  ];

  nix = {
    allowedUsers = ["@builders"];
    trustedUsers = ["root" "@wheel"];
    buildCores = 0;
    maxJobs = lib.mkDefault 6; # "auto"
  };

  home-manager = {
    useUserPackages = true;
    useGlobalPkgs = true;
    extraSpecialArgs = config.home.specialArgs;
    users = {
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
  };

  documentation.nixos.enable = false;

  users.users = {
    root = {
      shell = pkgs.zsh;
    };
    arc = {
      isNormalUser = true;
      initialPassword = "hello";
      extraGroups = [ "wheel" "builders" "kvm" ];
      shell = pkgs.zsh;
    };
  };
  users.groups = {
    builders = { };
  };
  programs.zsh.enable = true;

  home.profiles = {
    base = lib.mkDefault true;
  };
}
