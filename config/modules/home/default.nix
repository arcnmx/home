{ ... }: {
  disabledModules = [
    "programs/git.nix"
  ];

  imports = [
    ./hm_git.nix
    ./deploy-home.nix
    ./home.nix
  ];
}
