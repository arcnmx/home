{ pkgs, options, config, lib, ... }: with lib; let
  inherit (config.boot.loader.efi) efiSysMountPoint;
  cfg = config.boot.loader.secure-boot;
  binaryGlobs = [
    "${efiSysMountPoint}/efi/nixos/*-${pkgs.hostPlatform.linux-kernel.target}.efi"
    "${efiSysMountPoint}/efi/BOOT/BOOTX64.EFI"
  ] ++ optional config.boot.loader.systemd-boot.enable "${efiSysMountPoint}/efi/systemd/systemd-bootx64.efi";
in {
  options.boot.loader.secure-boot = with types; {
    enable = mkEnableOption "secure boot signing" // {
      default = cfg.certPath != null;
    };
    keyPath = mkOption {
      type = nullOr path;
      default = null;
    };
    certPath = mkOption {
      type = nullOr path;
      default = null;
    };
    sbsigntool = mkOption {
      type = package;
      default = pkgs.sbsigntool;
      defaultText = "pkgs.sbsigntool";
    };
    openssl = mkOption {
      type = package;
      default = pkgs.openssl;
      defaultText = "pkgs.openssl";
    };
  };

  config = mkIf cfg.enable {
    system.activationScripts.sbsign = mkIf (cfg.keyPath != null) {
      text = ''
        for efi in ${toString binaryGlobs}; do
          if [[ -e "$efi" ]]; then
            ${cfg.sbsigntool}/bin/sbsign --key "${cfg.keyPath}" --cert "${cfg.certPath}" --output "$efi" "$efi"
          fi
        done
        ${cfg.openssl}/bin/openssl x509 -outform DER -in ${cfg.certPath} -out ${efiSysMountPoint}/efi/nixos/secureboot.der
      '';
    };
  };
}
