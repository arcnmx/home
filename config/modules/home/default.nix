{ ... }: {
  disabledModules = [
    "programs/git.nix"
  ];

  imports = [
    ./hm_git.nix
    ./yggdrasil-7n.nix
  ];
}
