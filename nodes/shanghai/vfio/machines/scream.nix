{ nixosConfig, config, lib, pkgs, ... }: with lib; {
  config = {
    scream = {
      enable = mkDefault true;
      mode = mkDefault "ivshmem";
      playback = {
        user = mkDefault "arc";
        package = mkDefault pkgs.scream-arc;
        latency = {
          target = mkDefault 16;
          max = mkDefault 50;
        };
        cli.extraArgs = [ "-v" ];
      };
    };
  };
}
