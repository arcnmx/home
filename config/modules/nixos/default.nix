{ ... }: {
  disabledModules = [
    "services/networking/connman.nix"
  ];

  imports = [
    ./yggdrasil-7n.nix
    ./nixbld.nix
    ./connman.nix
  ];
}
