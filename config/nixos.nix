{ tf, config, lib, ... }: with lib; let
  nixosConfig = config;
  user = { config, ... }: {
    imports = nixosConfig.home.extraModules ++ [
      ./home.nix
    ];
  };
in {
  imports = [
    ../nodes/nixos.nix
  ];

  options.home = {
    profileSettings.gensokyo.zone = mkOption {
      type = types.nullOr types.str;
      default = findFirst (k: hasSuffix k (toString config.networking.domain)) null (mapAttrsToList (_: zone: zone.zone) tf.dns.zones);
    };
  };

  config.home-manager = {
    extraSpecialArgs = config.home.specialArgs;
    users = {
      arc = user;
      root = { lib, ... }: {
        imports = [user];
      };
    };
  };
}
