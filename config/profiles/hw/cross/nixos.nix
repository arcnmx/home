{ pkgs, config, lib, ... }: with lib; {
  options = {
    home.profiles.hw.cross = mkEnableOption "Cross";
    home.profileSettings.cross = {
      aarch64 = mkOption {
        type = types.bool;
        default = true;
      };
      armv7l = mkOption {
        type = types.bool;
        default = false;
      };
    };
  };

  config = mkIf config.home.profiles.hw.cross {
    boot.binfmt = {
      emulatedSystems = mkIf config.home.profileSettings.cross.aarch64 [ "aarch64-linux" ];
      registrations.aarch64-linux = mkIf config.home.profileSettings.cross.aarch64 {
        interpreter = mkForce "${pkgs.qemu-vfio or pkgs.qemu}/bin/qemu-aarch64";
      };
    };

    nix = mkIf config.home.profileSettings.cross.armv7l {
      binaryCaches = [ "https://arm.cachix.org/" ];
      binaryCachePublicKeys = [ "arm.cachix.org-1:5BZ2kjoL1q6nWhlnrbAl+G7ThY7+HaBRD9PZzqZkbnM=" ];
    };
  };
}
