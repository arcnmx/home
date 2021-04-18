{ config, lib, ... }: with lib; let
  cfg = config.home.nixbld;
in {
  options.home.nixbld.enable = mkEnableOption "distributed build user";

  config = mkMerge [
    (mkIf cfg.enable {
      users.users.nixbld = {
        isSystemUser = true;
        extraGroups = ["builders"];
        useDefaultShell = true;
        openssh.authorizedKeys.keyFiles = [
          ./nixbld.pub
        ];
      };
      nix.trustedUsers = ["nixbld"]; # TODO: this shouldn't strictly be necessary? (https://github.com/NixOS/nix/issues/2789)
    })
  ];
}
