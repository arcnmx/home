{ config, lib, ... }: with lib; {
  options.xdg.dataDirs = mkOption {
    type = types.listOf types.str;
    default = [ ];
  };
  config.xdg.dataFile = mapListToAttrs (dir: nameValuePair "${dir}/.keep" {
    text = "";
  }) config.xdg.dataDirs;
}
