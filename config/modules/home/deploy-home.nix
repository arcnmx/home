{ config, lib, ... }: with lib; let
  collectFailed = cfg:
    map (x: x.message) (filter (x: !x.assertion) cfg.assertions);

  showWarnings = res:
    let
      f = w: x: builtins.trace "[1;31mwarning: ${w}[0m" x;
    in
      fold f res res.warnings;

  config' = showWarnings (
    let
      failed = collectFailed config;
      failedStr = concatStringsSep "\n" (map (x: "- ${x}") failed);
    in
      if failed == []
      then config
      else throw "\nFailed assertions:\n${failedStr}"
  );
  cfg = config.deploy;
in {
  options.deploy = {
    config = mkOption {
      type = types.unspecified;
    };
    home = mkOption {
      type = types.unspecified;
    };
  };
  config.deploy = {
    config = config';
    home = cfg.config.home.activationPackage;
  };
}
