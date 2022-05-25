{ pkgs, options, config, lib, ... }: with lib; let
  uboot = pkgs.buildUBoot {
    patches = [
      ./Pine64-PineCube-uboot-support.patch
    ];
    defconfig = "pinecube_defconfig";
    extraConfig = concatStringsSep "\n" [
      "CONFIG_CMD_BOOTMENU=y"
      #"CONFIG_LOG=y" "CONFIG_LOGLEVEL=6"
      #CONFIG_EXTRA_ENV_SETTINGS= # set uboot env defaults
    ];
    extraMeta.platforms = ["armv7l-linux"];
    filesToInstall = ["u-boot-sunxi-with-spl.bin"];
  };
in {
  config = {
    nixpkgs = {
      config = {
        pulseaudio = false;
      };
      crossOverlays = [
        (import ./overlay.nix)
      ];
      crossSystem = import ./system.nix { inherit systems; };
    };
    boot = {
      loader.grub.enable = false;
      loader.generic-extlinux-compatible.enable = true;
      consoleLogLevel = 7;

      # cma is 64M by default which is waay too much and we can't even unpack initrd
      kernelParams = [ "console=ttyS0,115200n8" "cma=32M" ];
      kernelModules = [ "spi-nor" ]; # Not sure why this doesn't autoload. Provides SPI NOR at /dev/mtd0
      extraModulePackages = [ config.boot.kernelPackages.rtl8189es ];
      enableContainers = false;
      kernel = {
        customBuild = true;
        bleedingEdge = true;
        extraPatches = [
          { name = "pine64-pinecube";
            patch = ./Pine64-PineCube-support.patch;
          }
        ];
      };
      initrd = {
        includeDefaultModules = false;
        availableKernelModules = lib.mkForce [
          "mmc_block"
          "usbhid"
          "hid_generic" "hid_lenovo" "hid_apple" "hid_roccat"
          "hid_logitech_hidpp" "hid_logitech_dj" "hid_microsoft"
        ];
      };
    };
    hardware.enableRedistributableFirmware = lib.mkForce false;
    ${if options ? sdImage then "sdImage" else null} = {
      populateFirmwareCommands = "";
      populateRootCommands = ''
        mkdir -p ./files/boot
        ${config.boot.loader.generic-extlinux-compatible.populateCmd} -c ${config.system.build.toplevel} -d ./files/boot
      '';
      postBuildCommands = ''
        dd if=${uboot}/u-boot-sunxi-with-spl.bin of=$img bs=1024 seek=8 conv=notrunc
      '';
    };
    systemd.watchdog.timeout = "16s"; # sunxi-wdt supports limited timeout intervals

    #security.polkit.enable = mkDefault false;
    security.audit.enable = mkDefault false;
    # environment.noXlibs sets `overlays` and not `crossOverlays`, so implement it manually instead...
    programs.ssh.setXAuthLocation = false;
    security.pam.services.su.forwardXAuth = mkForce false;
    fonts.fontconfig.enable = false;

    sound.enable = mkDefault true;

    networking.wireless.enable = mkDefault true;
  };
}
