{ pkgs, lib, config, ... }: with lib; let
  cfg = config.hardware.vfio;
  inherit (cfg.qemu) machines;
  cowEnable = config.hardware.vfio.qemu.machines.hourai-nocow.enable;
  toggleSharedDisks = { ... }: {
    disks.games-adata.enable = cowEnable;
    disks.games-sn770.enable = true;
  };
in {
  config = {
    hardware.vfio = {
      qemu.machines = rec {
        macos = { config, ... }: {
          imports = [ ./common.nix ./macos-q35.nix ];
          config = {
            name = "hourai-macos";
            uuid = "319232b9-c25e-41eb-81c2-2b30cf191181";
            memory.sizeMB = 12 * 1024;
            smp.settings.threads = 2;
            disks = {
              newmac = {
                ide.slot = 0;
                path = "/dev/disk/by-partlabel/vm-osx";
              };
            };
          };
        };
        hourai3080 = { config, ... }: {
          imports = [ ./hourai.nix toggleSharedDisks ];
          config = {
            vfio.gpu = "rtx3080";
          };
        };
        hourai1650 = { ... }: {
          imports = [ ./hourai.nix toggleSharedDisks ];
          enable = false;
          vfio.gpu = "gtx1650";
        };
        hourai-nocow = { ... }: {
          inherit (machines.goliath1650) enable;
          imports = [ hourai3080 ];
          scream.enable = false;
          hotplug.enable = false;
          disks.games-adata.enable = mkForce false;
        };
        goliath1650 = { config, ... }: {
          imports = [ ./goliath.nix toggleSharedDisks ];
          config = {
            enable = false;
            vfio.gpu = "gtx1650";
          };
        };
        goliath3080 = { config, ... }: {
          imports = [ ./goliath.nix toggleSharedDisks ];
          config = {
            inherit (machines.goliath1650) enable;
            vfio.gpu = "rtx3080";
          };
        };
      };
    };
  };
}
