{
  home.packages = import ./packages.nix;
} // { home = (import ../dotfiles/laptop); }
