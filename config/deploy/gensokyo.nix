{ ... }: {
  config.network.nodes = {
    satorin = { config, ... }: {
      imports = [../nixos.nix];

      networking = {
        hostName = "satorin";
      };
    };

    shanghai = { config, ... }: {
      imports = [../nixos.nix];

      networking = {
        hostName = "shanghai";
      };
    };
  };
}
