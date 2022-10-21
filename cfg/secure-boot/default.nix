{ meta, tf, pkgs, config, lib, ... }: with lib; let
  inherit (tf) resources;
in {
  config = {
    boot.loader.secure-boot = mkIf tf.state.enable {
      enable = mkDefault true;
      keyPath = config.secrets.files.secureboot-key.path;
      certPath = config.secrets.files.secureboot-cert.path;
    };
    secrets.files = {
      secureboot-key.text = resources.secureboot_key.refAttr "private_key_pem";
      secureboot-cert.text = resources.secureboot_cert_pem.refAttr "content";
    };
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
