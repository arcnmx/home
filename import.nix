let
  channelConfigPath = ./config/channels;
  channelConfig = import channelConfigPath;
  args = {
    inherit channelConfig channelConfigPath;
  };
in (import ./channels args)
