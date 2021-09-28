{ config, pkgs, lib, ... }: with lib; let
  windows = pkgs.writeShellScriptBin "windows" ''
    tmux new-session -d -s windows \
      "cd ~/projects/arc.github/vfio; echo vm windows run; $SHELL -i" \; \
      split-window -h "$SHELL -ic ryzen-watch" \; \
      select-pane -L \; \
      split-window -dv "top -H" \; \
      attach
  '';
in {
  options = {
    home.profiles.vfio = mkEnableOption "VFIO";
  };

  config = mkIf config.home.profiles.vfio {
    home.packages = [
      windows
    ];
  };
}
