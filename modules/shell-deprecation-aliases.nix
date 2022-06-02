{ config, lib, ... }: with lib; let
  shellFunAlias = command: replacement: ''
    if [[ ! -t 0 ]]; then
      command ${command} $@
    else
      echo 'use ${replacement}!'
    fi
  '';
in {
  options.home.shell.deprecationAliases = mkOption {
    type = types.attrsOf types.str;
    default = { };
  };
  config.home.shell.functions = mapAttrs shellFunAlias config.home.shell.deprecationAliases;
}
