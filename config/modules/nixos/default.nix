{ ... }: {
  disabledModules = [
    "services/networking/connman.nix"
  ];

  imports = [
    ./nixbld.nix
    ./connman.nix
  ];
}
