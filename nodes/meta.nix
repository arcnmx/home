{ lib, inputs, trusted, ... }: {
  imports = [
    ./shanghai/meta.nix
    #./satorin/meta.nix
  ];

  nixos = {
    extraModules = [
      ./nixos.nix
      inputs.home-manager.nixosModules.home-manager
      inputs.linuxPackages.nixosModules.default
      inputs.meta.nixosModules.default
      inputs.base16.nixosModules.base16 # TODO: .default
    ];
    specialArgs = {
      inherit trusted;
    };
  };
}
