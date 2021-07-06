{ modulesPath, ... }: {
  disabledModules = [
    (modulesPath + "/services/networking/connman.nix")
    "services/networking/connman.nix"
  ];

  imports = [
    ./deploy-switch.nix
    ./deploy-state.nix
    ./deploy-personal.nix
    ./deploy-tf.nix
    ./matrix-synapse-bridges.nix
    ./kernel.nix
    ./nixbld.nix
    ./connman.nix
    ./home.nix
  ];
}
