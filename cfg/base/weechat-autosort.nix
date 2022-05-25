{ pkgs, config, lib, ... }: with lib; let
  cfg = config.programs.weechat.autosort;
in {
  options.programs.weechat.autosort = {
    enable = mkEnableOption "weechat autosort plugin";
    rules = mkOption {
      type = types.listOf types.str;
      default = [ ];
    };
    signals = mkOption {
      type = types.listOf types.str;
      default = [ "buffer_opened" "buffer_merged" "buffer_unmerged" "buffer_renamed" ];
    };
    # TODO: hiddenBuffers
    shortNames = {
      first = mkOption {
        type = types.listOf types.str;
        default = [ ];
      };
      last = mkOption {
        type = types.listOf types.str;
        default = [ ];
      };
    };
  };
  config.programs.weechat = {
    scripts = mkIf cfg.enable [ pkgs.weechatScripts.weechat-autosort ];
    config = mkIf cfg.enable {
      autosort = {
        sorting = {
          signals = toString cfg.signals;
        };
        v3 = mapAttrs (_: builtins.toJSON) {
          rules = cfg.rules;
          helpers = { };
        };
      };
    };
    autosort.rules = mkMerge [
      (mkIf (cfg.shortNames.first != [ ]) [ (
        "\${"
        + concatStringsSep "," ([
          "info:autosort_order"
          "\${info:autosort_escape,\${buffer.full_name}}"
        ] ++ cfg.shortNames.first ++ singleton "*")
        + "}"
      ) ])
      (mkIf (cfg.shortNames.last != [ ]) [ (
        "\${"
        + concatStringsSep "," ([
          "info:autosort_order"
          "\${info:autosort_escape,\${buffer.full_name}}"
        ] ++ singleton "*" ++ cfg.shortNames.last)
        + "}"
      ) ])
    ];
  };
}
