{ config, pkgs, lib, ... }: with lib; let
  windows = pkgs.writeShellScriptBin "windows" ''
    tmux new-session -d -s windows \
      "cd ~/projects/arc.github/vfio; echo vm windows run; $SHELL -i" \; \
      split-window -h "top -H" \; \
      split-window -v "watch -t 'cat /proc/cpuinfo|grep MHz'" \; \
      select-pane -L \; \
      split-window -dv "watch -t sensors -c /etc/sensors3.conf 'nct6795-*' 'k10temp-pci-*'" \; \
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
