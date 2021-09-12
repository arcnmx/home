{ config, pkgs, lib, ... }: with lib; {
  options = {
    home.profiles.hw.pinecube = mkEnableOption "Pinecube";
  };

  config = mkIf config.home.profiles.hw.pinecube {
  };
}
