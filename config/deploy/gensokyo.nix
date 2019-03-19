{
  network = {
    enableRollback = true; # just for keeping gcroots around
  };

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
}
