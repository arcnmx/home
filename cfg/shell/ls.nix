{ pkgs, config, lib, ... }: with lib; {
  programs.exa = {
    enable = !config.home.minimalSystem;
    enableAliases = mkDefault false;
    extraOptions = [
      "--time-style" "long-iso"
    ];
  };
  home.shell.aliases = mkMerge [
    (mkIf config.programs.exa.enable {
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
