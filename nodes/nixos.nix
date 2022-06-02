{ pkgs, config, lib, name, ... }: {
  imports = [
    ../cfg/base
  ];

  networking.hostName = lib.mkDefault name;

  nix = {
    settings = {
      allowed-users = ["@builders"];
      trusted-users = ["root" "@wheel"];
      cores = 0;
      max-jobs = lib.mkDefault 6; # "auto"
    };
    nrBuildUsers = 32; # XXX: workaround for infinite recursion due to `nix.settings` being freeform
  };

  home-manager = {
    useUserPackages = true;
    useGlobalPkgs = true;
    sharedModules = [ ./home.nix ];
    users = {
      arc = {
        systemd.user.startServices = true;
      };
      root = { };
    };
  };

  documentation.nixos.enable = false;
  programs.zsh.enable = true;

  users = {
    users = {
      root = {
        shell = pkgs.zsh;
      };
      arc = {
        isNormalUser = true;
        extraGroups = [ "wheel" "builders" "kvm" "video" ] ++ lib.optional config.virtualisation.docker.enable "docker";
        shell = pkgs.zsh;
      };
    };
    groups = {
      builders = { };
    };
  };
}
