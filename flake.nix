{
  inputs = {
    flakelib = {
      url = "github:flakelib/fl";
    };
    nixpkgs = { };
  };
  outputs = { self, nixpkgs, flakelib, ... }@inputs: let
    nixlib = nixpkgs.lib;
  in flakelib {
    inherit inputs;
    packages = {
      esphome-fonts = { linkFarm, cozette }: linkFarm "esphome-fonts" [
        {
          name = "cozette.bdf";
          path = "${cozette}/share/fonts/misc/cozette.bdf";
        }
      ];
    };
    devShells = {
      default = { mkShell, writeShellScriptBin, gnumake, esphome, esphome-fonts }: let
        esphome-wrapper = writeShellScriptBin "esphome" ''
          exec ${nixlib.getExe esphome} -s fonts_root ${esphome-fonts} "$@"
        '';
      in mkShell {
        nativeBuildInputs = [
          esphome-wrapper
          gnumake
        ];
      };
    };
  };
}
