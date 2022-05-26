{ outputs, inputs, lib }: let
  eval = lib.evalModules {
    modules = [
      ./meta
    ];
    specialArgs = {
      inherit lib inputs;
      trusted = import ./meta/trusted.nix { inherit lib inputs; };
    };
  };
in eval.config
