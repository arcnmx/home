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
      flash-espresense = { writeShellScriptBin, esptool, jq, curl }: let
        bins = [ esptool jq curl ];
      in writeShellScriptBin "flash-espresense" ''
        export PATH=''${PATH-}:${nixlib.makeBinPath bins}
        source ${./flash-espresense.sh}
      '';
    };
    devShells = {
      default = { mkShell, writeShellScriptBin, sops, gnumake, esptool, esphome, esphome-fonts }: let
        esphome-wrapper = writeShellScriptBin "esphome" ''
          exec ${nixlib.getExe esphome} -s fonts_root ${esphome-fonts} "$@"
        '';
        flash-espresense = writeShellScriptBin "flash-espresense" ''
          exec nix run --quiet .#flash-espresense ''${FLAKE_OPTS-} -- "$@"
        '';
      in mkShell {
        nativeBuildInputs = [
          flash-espresense
          esphome-wrapper
          esptool
          gnumake
          sops
        ];
      };
    };
  };
}
