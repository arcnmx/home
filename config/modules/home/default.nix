{ ... }: {
  disabledModules = [
    "programs/git.nix"
    "programs/vim.nix"
  ];

  imports = [
    ./hm_git.nix
    ./hm_vim.nix
    ./deploy-home.nix
    ./home.nix
  ];
}
