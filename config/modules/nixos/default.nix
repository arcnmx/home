{ ... }: {
  disabledModules = [
    "services/networking/connman.nix"
  ];

  imports = [
    ./deploy-switch.nix
    ./nixbld.nix
    ./connman.nix
  ];
}
