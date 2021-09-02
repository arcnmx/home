{ modulesPath, ... }: {
  disabledModules = [
    (modulesPath + "/services/networking/connman.nix")
    "services/networking/connman.nix"
  ];

  imports = [
    ./deploy-switch.nix
    ./deploy-personal.nix
    ./deploy-tf.nix
    ./deploy-domains.nix
    ./matrix-synapse-bridges.nix
    ./kernel.nix
    ./nixbld.nix
    ./connman.nix
    ./home.nix
  ];
}
