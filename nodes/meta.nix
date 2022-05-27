{ lib, inputs, trusted, ... }: {
  imports = [
    ./shanghai/meta.nix
    #./satorin/meta.nix
  ];

  nixos = {
    extraModules = let
      meta = inputs.meta.nixosModules;
    in [
      ./nixos.nix
      inputs.home-manager.nixosModules.home-manager
      inputs.linuxPackages.nixosModules.default
      meta.default # TODO: import per profile instead where needed!
      inputs.base16.nixosModules.base16 # TODO: .default

      inputs.meta.modules.extern
    ];
    specialArgs = {
      inherit trusted;
    };
  };
}
