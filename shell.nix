{ pkgs ? import <nixpkgs> { } }: with pkgs; let
  esphome = pkgs.esphome.overridePythonAttrs (old: {
    propagatedBuildInputs = old.propagatedBuildInputs ++ [ python3Packages.requests ];
  });
in mkShell {
  nativeBuildInputs = [ esphome gnumake ];
}
