{ meta, lib, ... }: with lib; {
  options = {
    network = {
      yggdrasil = mkOption {
        type = types.unspecified;
      };
      wan = mkOption {
        type = types.unspecified;
      };
    };
  };
  config = {
    network = {
      inherit (meta.network) yggdrasil wan;
    };
  };
}
