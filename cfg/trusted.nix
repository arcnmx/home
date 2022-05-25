{ lib, ... }: with lib; let
  trustedPath = ../config/profiles/trusted/nixos.nix;
  hasTrusted = builtins.pathExists trustedPath;
in {
  imports = optional hasTrusted trustedPath;
  config = {
    home.profiles.trusted = hasTrusted;
  };
}
