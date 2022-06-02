{ config, lib, ... }: with lib; let
in {
  options.xdg.open = mkOption {
    type = types.str;
    default = "${pkgs.xdg-open}/bin/xdg-open";
  };
}
