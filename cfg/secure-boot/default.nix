{ meta, tf, pkgs, config, lib, ... }: with lib; let
  inherit (tf) resources;
in {
  config = {
    boot.loader.secure-boot = mkIf tf.state.enable {
      enable = mkDefault true;
      keyPath = config.secrets.files.secureboot-key.path;
      certPath = "${pkgs.writeText "secureboot.pem" (resources.secureboot_cert_pem.getAttr "content")}";
    };
    secrets.files.secureboot-key.text = resources.secureboot_key.refAttr "private_key_pem";
    deploy.tf = {
      inherit (import ./tf.nix {
        inherit (config) networking;
        inherit (tf.runners) pkgs;
        inherit (tf) terraform;
        inherit meta resources lib;
      }) resources;
    };
  };
}
