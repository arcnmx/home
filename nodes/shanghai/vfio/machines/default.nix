{ pkgs, lib, config, ... }: with lib; {
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
          imports = [ ./hourai.nix ];
          config = {
            vfio.gpu = "gtx3080";
          };
        };
        hourai1650 = { ... }: {
          imports = [ ./hourai.nix ];
          vfio.gpu = "gtx1650";
        };
        hourai-nocow = { ... }: {
          imports = [ hourai3080 ];
          disks.games-adata.enable = false;
          disks.games-sn770.enable = false;
        };
        goliath1650 = { config, ... }: {
          imports = [ ./goliath.nix ];
          config = {
            vfio.gpu = "gtx1650";
          };
        };
        goliath3080 = { config, ... }: {
          imports = [ ./goliath.nix ];
          config = {
            vfio.gpu = "gtx3080";
          };
        };
      };
    };
  };
}
