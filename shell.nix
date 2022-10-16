{ pkgs ? import <nixpkgs> { } }: with pkgs; let
in mkShell {
  nativeBuildInputs = [ esphome gnumake ];
}
