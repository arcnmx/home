{ pkgs ? null }@args: import ../channels rec {
  ${if args ? pkgs then "pkgs" else null} = pkgs;
  channelConfigPath = ./channels;
  channelConfig = import channelConfigPath;
}
