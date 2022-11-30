{ config, lib, ... }: with lib; {
  home.shell = mkIf config.programs.tmux.enable {
    aliases = {
      tatt = "tmux att -t";
      tmain = "tatt main";
    };
    functions = {
      tnew = ''
        unset DISPLAY GPG_TTY SSH_TTY SSH_AUTH_SOCK SSH_CONNECTION SSH_CLIENT
        tmux new -s "$@"
      '';
    };
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
