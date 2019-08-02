{ ... }: {
  disabledModules = [
    "programs/git.nix"
    "programs/vim.nix"
    "programs/firefox.nix"
  ];

  imports = [
    ./hm_git.nix
    ./hm_vim.nix
    ./hm_firefox.nix
    ./yggdrasil-7n.nix
  ];
}
