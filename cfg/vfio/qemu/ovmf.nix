{ config, lib, pkgs, ... }: with lib; let
  cfg = config.ovmf;
in {
  options.ovmf = {
    enable = mkEnableOption "OVMF firmware" // {
      default = cfg.vars != null;
    };
    package.fd = mkOption {
      type = types.package;
      default = pkgs.OVMF.fd;
    };
    vars = mkOption {
      type = with types; nullOr path;
      default = config.state.path + "/vars.bin";
    };
  };
  config = mkIf cfg.enable {
    globals.isa-debugcon = mkIf config.debug.enable {
      iobase = "0x402";
    };
    drives = {
      ovmf-code.settings = {
        file = "${cfg.package.fd}/FV/OVMF_CODE.fd";
        "if" = "pflash";
        format = "raw";
        unit = 0;
        readonly = true;
      };
      ovmf-vars.settings = {
        file = cfg.vars;
        "if" = "pflash";
        format = "raw";
        unit = 1;
      };
    };
    exec.scriptText = mkBefore ''
      if [[ ! -e ${cfg.vars} ]]; then
        cp --no-preserve=mode,ownership ${cfg.package.fd}/FV/OVMF_VARS.fd ${cfg.vars}
      fi
    '';
    cli.boot.settings = {
      menu = true;
      strict = true;
      # splash-time = 10000;
    };
  };
}
