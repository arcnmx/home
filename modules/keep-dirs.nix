{ config, lib, ... }: with lib; let
  shellFunAlias = command: replacement: ''
    if [[ ! -t 0 ]]; then
      command ${command} $@
    else
      echo 'use ${replacement}!'
    fi
  '';
in {
  options.xdg.dataDirs = mkOption {
    type = types.listOf types.str;
    default = [ ];
  };
  config.xdg.dataFile = mapListToAttrs (dir: nameValuePair "${dir}/.keep" {
    text = "";
  }) config.xdg.dataDirs;
}
