{ config, lib, ... }: with lib; let
  cfg = config.home.nixbld;
in {
  options.home.nixbld.enable = mkEnableOption "distributed build user";

  config = mkMerge [
    (mkIf cfg.enable {
      users.groups.nixbld = { };
      users.users.nixbld = {
        isSystemUser = true;
        group = "nixbld";
        extraGroups = ["builders"];
        useDefaultShell = true;
        openssh.authorizedKeys.keyFiles = [
          ./nixbld.pub
        ];
      };
      nix.settings.trusted-users = ["nixbld"]; # TODO: this shouldn't strictly be necessary? (https://github.com/NixOS/nix/issues/2789)
    })
  ];
}
