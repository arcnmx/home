{ nixosConfig, config, pkgs, lib, ... }: with lib; let
  cfg = config.programs.screenstub;
  windows = pkgs.writeShellScriptBin "windows" ''
    tmux new-session -d -s windows \
      "$SHELL -i" \; \
      split-window -h "$SHELL -ic ryzen-watch" \; \
      select-pane -L \; \
      split-window -dv "top -H" \; \
      attach
  '';
  vm = nixosConfig.hardware.vfio.qemu.machines.${cfg.vm.name};
  inherit (cfg) modifierKey;
in {
  options = {
    programs.screenstub = {
      vm.name = mkOption {
        type = with types; nullOr str;
        default = null;
      };
      modifierKey = mkOption {
        type = types.str;
        default = "RightCtrl";
      };
    };
  };

  config = {
    home.packages = mkMerge [
      [ windows ]
      (mkIf (cfg.vm.name != null && vm.enable) [
        (mkIf vm.qga.enable vm.exec.qga)
        (mkIf vm.qmp.enable vm.exec.qmp)
      ])
    ];
    home.shell.aliases = mkIf (cfg.vm.name != null) {
      qga = mkIf vm.qga.enable vm.exec.qga.name;
      qmp = mkIf vm.qmp.enable vm.exec.qmp.name;
    };

    programs.screenstub = {
      enable = mkDefault true;
      settings = {
        qemu = mkMerge [
          (mapAttrs (_: mkOptionDefault) {
            driver = "virtio"; # input-linux
            routing = "virtio-host"; # qmp
          })
          (mkIf (cfg.vm.name != null) {
            qmp_socket = mkIf vm.qmp.enable (mkOptionDefault vm.qmp.path);
            ga_socket = mkIf vm.qga.enable (mkOptionDefault vm.qga.path);
          })
        ];
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
