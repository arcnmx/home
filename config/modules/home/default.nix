{ ... }: {
  disabledModules = [
    "programs/git.nix"
    "programs/vim.nix"
  ];

  imports = [
    ./hm_git.nix
    ./hm_vim.nix
    ./yggdrasil-7n.nix
  ];
}
