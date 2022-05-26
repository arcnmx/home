{ inputs, lib }: let
  inherit (lib) List Set;
  enable = inputs ? trusted.nixosModules.test;
  importModule = root: path: List.optional enable (Set.at (List.One root ++ List path) inputs.trusted);
in {
  inherit enable;
  import = {
    nixos = importModule "nixosModules";
    home = importModule "homeModules";
    meta = importModule "modules";
  };
}
