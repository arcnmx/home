{ inputs, config, lib, ... }: with lib; let
  inherit (config.boot.loader) secure-boot;
in {
  # https://github.com/NixOS/nixpkgs/pull/53901
  # flake inputs.hmenke-modules.url = "github:hmenke/nixos-modules"
  imports = [ inputs.hmenke-modules.nixosModules.systemd-boot ];
  config.boot.loader = {
    secure-boot.enable = mkForce false;
    systemd-boot = {
      signed = true;
      signing-key = secure-boot.keyPath;
      signing-certificate = secure-boot.certPath;
    };
  };
}
