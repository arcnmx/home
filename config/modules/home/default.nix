{ ... }: {
  disabledModules = [
    "services/mpd.nix"
    "programs/git.nix"
    "programs/vim.nix"
    "programs/firefox.nix"
  ];

  imports = [
    ./hm_mpd.nix
    ./hm_git.nix
    ./hm_vim.nix
    ./hm_firefox.nix
    ./deploy-home.nix
  ];
}
