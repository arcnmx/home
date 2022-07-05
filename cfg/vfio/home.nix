{ nixosConfig, config, pkgs, lib, ... }: with lib; let
  windows = pkgs.writeShellScriptBin "windows" ''
    tmux new-session -d -s windows \
      "cd ~/projects/arc.github/vfio; echo vm windows run; $SHELL -i" \; \
      split-window -h "$SHELL -ic ryzen-watch" \; \
      select-pane -L \; \
      split-window -dv "top -H" \; \
      attach
  '';
  rundir = "/run/user/${toString nixosConfig.users.users.${config.home.username}.uid}/vfio/running";
  qmp_socket = rundir + "/qmp";
  ga_socket = rundir + "/qga";
  inherit (config.programs.screenstub) modifierKey;
in {
  options = {
    programs.screenstub = {
      modifierKey = mkOption {
        type = types.str;
        default = "RightCtrl";
      };
    };
  };

  config = {
    home.packages = [
      windows
    ];
    home.shell.functions = {
      qga = ''
        QEMUCOMM_QGA_SOCKET_PATH=${ga_socket} nix shell github:arcnmx/qemucomm#qemucomm -c qga "$@"
      '';
      qmp = ''
        QEMUCOMM_QMP_SOCKET_PATH=${qmp_socket} nix shell github:arcnmx/qemucomm#qemucomm -c qmp "$@"
      '';
    };

    programs.screenstub = {
      enable = mkDefault true;
      settings = {
        qemu = mapAttrs (_: mkOptionDefault) {
          driver = "virtio"; # input-linux
          routing = "virtio-host"; # qmp
          inherit qmp_socket ga_socket;
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
