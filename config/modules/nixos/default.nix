{ modulesPath, ... }: {
  disabledModules = [
    (modulesPath + "/services/networking/connman.nix")
    "services/networking/connman.nix"
  ];

  imports = [
    ./deploy-switch.nix
    ./nixbld.nix
    ./connman.nix
    ./home.nix
    ../compat.nix
  ];
}
