{ config }: {
  schemes = with config.base16.alias; [ dark light ];
  alias.light = "atelier.atelier-sulphurpool-light";
  alias.dark = "unclaimed.monokai";
  # some themes that look neat: material-palenight, onedark, rebecca, snazzy, tomorrow-night{,-eighties}, gruvbox-light-medium, atelier-sulphurpool{,-light?}, heetch-light?, helios, material-lighter?, monokai
  # note: nix run nixpkgs.base16-shell-preview -c base16-shell-preview
  # best so far: atelier-sulphurpool-light, gruvbox-light-medium, rebecca?
}
