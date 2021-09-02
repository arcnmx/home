{ config, lib, ... }: with lib; {
  base16 = mkIf config.home.profiles.base {
    schemes = mkMerge [ {
      light = "atelier.atelier-sulphurpool-light";
      dark = "unclaimed.monokai";
    } {
      dark.ansi.palette = {
        background.alpha = "ee00";
        rxvt-underline = mkForce config.base16.schemes.dark.ansi.palette.base09.set;
      };
      light.ansi.palette.background.alpha = "d000";
    } ];
    defaultSchemeName = "dark";
  };
  # some themes that look neat: material-palenight, onedark, rebecca, snazzy, tomorrow-night{,-eighties}, gruvbox-light-medium, atelier-sulphurpool{,-light?}, heetch-light?, helios, material-lighter?, monokai
  # note: nix run nixpkgs.base16-shell-preview-arc -c base16-shell-preview
  # best so far: atelier-sulphurpool-light, gruvbox-light-medium, rebecca?
}
