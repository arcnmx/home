{ lib, ... }: with lib; {
  options.home = {
    profiles = {
      host.gensokyo = mkEnableOption "network: gensokyo";
    };
  };
}
