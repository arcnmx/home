{ pkgs, config, lib, ... }: with lib; {
  programs.exa.enable = !config.home.minimalSystem;
  home.shell.aliases = mkMerge [
    (mkIf config.programs.exa.enable {
      exa = "exa --time-style long-iso";
      ls = "exa -G";
      la = "exa -Ga";
      ll = "exa -l";
      lla = "exa -lga";
    })
    (mapAttrs (_: mkOptionDefault) {
      ls = "ls --color=auto";
      la = "ls -A";
      ll = "ls -lh";
      lla = "ls -lhA";
    })
    (mkIf pkgs.hostPlatform.isDarwin {
      ls = mkDefault "ls -G";
    })
  ];
}
