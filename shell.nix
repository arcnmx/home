{ pkgs ? import <nixpkgs> { } }: with pkgs; with lib; let
  fonts = pkgs.linkFarm "esphome-fonts" [
    {
      name = "cozette.bdf";
      path = "${cozette}/share/fonts/misc/cozette.bdf";
    }
  ];
  esphome = pkgs.writeShellScriptBin "esphome" ''
    set -eu
    ${getExe pkgs.esphome} -s fonts_root "$ESPHOME_FONTS_ROOT" "$@"
  '';
in mkShell {
  nativeBuildInputs = [ esphome gnumake ];

  ESPHOME_FONTS_ROOT = fonts;
}
