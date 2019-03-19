{ pkgs ? null }: import ../channels rec {
  inherit pkgs;
  channelConfigPath = ./channels;
  channelConfig = import channelConfigPath;
}
