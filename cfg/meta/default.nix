{ lib, inputs, trusted, ... }: let
  inherit (lib) options types;
in {
  imports = let
    meta = inputs.meta.modules;
  in [
    meta.nodes #meta.run
    ../../nodes/meta.nix
  ];

  options = {
  };
  config = {
    /*runners = {
      lazy = {
        inherit inputs;
        args = [ "--show-trace" ];
      };
    };*/
  };
}
