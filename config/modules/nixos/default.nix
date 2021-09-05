{ modulesPath, ... }: {
  imports = [
    ./deploy-switch.nix
    ./deploy-personal.nix
    ./deploy-tf.nix
    ./deploy-domains.nix
    ./matrix-synapse-bridges.nix
    ./kernel.nix
    ./nixbld.nix
    ./home.nix
  ];
}
