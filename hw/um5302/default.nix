{ config, pkgs, lib, ... }: with lib; let
  cfg = config.home.hw.um5302;
in {
  key = "Zenbook S 13 OLED (UM5302)";
  imports = [
    ../ryzen
    ../amdgpu
    ../../cfg/laptop
  ];

  config = {
    home-manager.users.arc = { ... }: {
      imports = [ ./home.nix ];
    };
    hardware.display.dpms.standbyMinutes = 3;

    boot = {
      kernel = {
        arch = "znver3";
        extraPatches = [
          {
            name = "cs35l42-hda-no-acpi-dsd-csc3551";
            patch = pkgs.fetchurl {
              name = "cs35l42-hda-no-acpi-dsd-csc3551.patch";
              url = "https://aur.archlinux.org/cgit/aur.git/plain/cs35l42-hda-no-acpi-dsd-csc3551.patch?h=linux-mainline-um5302ta&id=97f359d6c6a726f2ed790d367ed2fc4dae2a5d30";
              sha256 = "e2613a7336bd01a2727ca2fc37e1000be6e9d30632aec56eff334e3f7b23e487";
            };
          }
        ];
      };
      initrd = {
        availableKernelModules = [
          "nvme" "xhci_pci" "ehci_pci" "ahci" "sd_mod" "usbhid"
        ];
        dsdt = {
          version = "0107200a";
          patch = {
            version = "01072009";
            table = ./dsdt.dat;
            s3.enable = true;
          };
        };
      };
    };

    services.fprintd.enable = mkDefault true;
    networking.wireless.mainInterface.name = mkDefault "wlp1s0";

    services.xserver = {
      defaultDepth = mkIf false 30; # XXX: this breaks firefox webgl due to a "badpbuffer" error

      libinput = {
        enable = true;
      };
    };

    # workaround for a bug where the backlight resets to a default level when waking from dpms
    systemd.services.dpms-standby = mkIf config.services.dpms-standby.enable {
      serviceConfig.ExecStop = [
        (with pkgs; writeShellScript "restore-backlight" ''
          ${getExe acpilight} -set $(${getExe acpilight} -get)
        '')
      ];
    };
  };
}
