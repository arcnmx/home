{ config, pkgs, lib, ... }: with lib; let
  windows = pkgs.writeShellScriptBin "windows" ''
    tmux new-session -d -s windows \
      "cd ~/projects/arc.github/vfio; echo vm windows run; $SHELL -i" \; \
      split-window -h "$SHELL -ic ryzen-watch" \; \
      select-pane -L \; \
      split-window -dv "top -H" \; \
      attach
  '';
  inherit (config.programs.screenstub) modifierKey;
in {
  options = {
    home.profiles.vfio = mkEnableOption "VFIO";
    programs.screenstub = {
      modifierKey = mkOption {
        type = types.str;
        default = "RightCtrl";
      };
    };
  };

  config = {
    home.packages = mkIf config.home.profiles.vfio [
      windows
    ];

    programs.screenstub = {
      enable = mkIf config.home.profiles.vfio (mkDefault true);
      settings = {
        qemu = mapAttrs (_: mkOptionDefault) {
          driver = "virtio"; # input-linux
          routing = "virtio-host"; # qmp
          qmp_socket = "/run/user/1000/vfio/running/qmp";
          ga_socket = "/run/user/1000/vfio/running/qga";
        };
        key_remap = mapAttrs (_: mkOptionDefault) {
          # https://docs.rs/input-linux/*/input_linux/enum.Key.html
          LeftMeta = "RightAlt";
          CapsLock = "LeftAlt";
          RightAlt = "LeftMeta";
        };
        hotkeys = [
          {
            triggers = singleton "Q";
            modifiers = singleton modifierKey;
            events = [
              "show_host"
              "shutdown"
              "exit"
            ];
          }
          {
            triggers = singleton "R";
            modifiers = singleton modifierKey;
            events = singleton "reboot";
          }
          {
            triggers = singleton "P";
            modifiers = singleton modifierKey;
            events = singleton "toggle_show";
          }
          {
            triggers = singleton "H";
            modifiers = singleton modifierKey;
            events = singleton {
              toggle_grab.x.mouse = true;
            };
          }
        ];
        exit_events = mkOptionDefault [
          "show_host"
          "unstick_guest"
          "unstick_host"
        ];
      };
    };
  };
}
