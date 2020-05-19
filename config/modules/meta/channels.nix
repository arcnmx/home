{ lib, ... }: with lib; {
  options.channels = mkOption {
    type = types.unspecified;
  };
}
