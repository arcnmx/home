{ config, lib, ... }: with lib; {
  home.shell.aliases = mkIf config.programs.tmux.enable {
    tnew = "tmux new -s";
    tatt = "tmux att -t";
    tmain = "tatt main";
  };
  programs.tmux = {
    enable = true;
    aggressiveResize = true;
    baseIndex = 1;
    escapeTime = 1;
    historyLimit = 50000;
    keyMode = "vi";
    resizeAmount = 4;
    customPaneNavigationAndResize = true;
    shortcut = "a";
    terminal = "screen-256color";
    tmuxp.enable = true;
    extraConfig = ''
      source-file ${./tmux.conf}
    '';
  };
}
