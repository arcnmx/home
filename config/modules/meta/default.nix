{ ... }: {
  imports = [
    ./channels.nix
    ./home.nix
    ./network.nix
    ./deploy.nix
    ./deploy-personal.nix
    ./deploy-archive.nix
    ./deploy-repos.nix
  ];
}
