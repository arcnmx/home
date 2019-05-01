{ config, lib, ... }: with lib; let
  cfg = config.home.nixbld;
in {
  options.home.nixbld.enable = mkEnableOption "distributed build user";

  config = mkMerge [
    (mkIf cfg.enable {
      users.users.nixbld = {
        isNormalUser = false;
        extraGroups = ["builders"];
        openssh.authorizedKeys.keyFiles = [
          config.keychain.keys.nixbld.path.public
        ];
      };
      nix.trustedUsers = ["nixbld"]; # TODO: this shouldn't strictly be necessary? (https://github.com/NixOS/nix/issues/2789)
    })
    {
      keychain.keys.nixbld.public = ./nixbld.pub;
    }
  ];
}
