{ ... }: {
  disabledModules = [
    "programs/git.nix"
  ];

  imports = [
    ./hm_git.nix
  ];
}
