{ nixosConfig, config, trusted, lib, ... }: with lib; let
  inherit (nixosConfig.hardware.vfio) disks;
in {
  imports = [
    ./common.nix ./scream.nix ./virtio.nix
    ./windows-i440fx.nix
    ./dmi-gigabyte.nix
    ./vfio.nix
  ] ++ trusted.import.nixos "vfio/machines/hourai";
  config = {
    enable = true;
    name = "hourai";
    virtio.enable = true;
    memory.sizeMB = 8 * 1024;
    smp = {
      settings = {
        threads = 1;
        cores = nixosConfig.hardware.cpu.info.cores / 2;
      };
    };
    systemd.depends = [
      (mkIf config.disks.games-adata.enable disks.cow.windows-games-adata-arc.systemd.id)
      (mkIf config.disks.games-adata-arc.enable "windows-games-adata-arc.service")
      disks.mapped.windows-games-sabrent.systemd.id
      disks.mapped.windows-games-bpx.systemd.id
      disks.mapped.windows-games.systemd.id
    ];
    disks = {
      windows = {
        scsi.lun = 0;
        path = "/dev/disk/by-partlabel/windows-vm-sabrent";
      };
      games-plextor = {
        scsi.lun = 1;
        inherit (disks.mapped.windows-games) path;
      };
      intel = {
        scsi = {
          driver = "scsi-block";
          lun = 2;
        };
        path = "/dev/disk/by-id/ata-INTEL_SSDSC2BP480G4_BTJR442300QQ480BGN";
      };
      games-sabrent = {
        scsi.lun = 4;
        inherit (disks.mapped.windows-games-sabrent) path;
      };
      games-adata = {
        scsi.lun = 5;
        inherit (disks.cow.windows-games-adata-arc) path;
      };
      games-adata-arc = {
        enable = !config.disks.games-adata.enable;
        scsi.lun = config.disks.games-adata.scsi.lun;
        path = "/dev/disk/windows-games-adata-arc";
      };
      games-bpx = {
        scsi.lun = 6;
        inherit (disks.mapped.windows-games-bpx) path;
      };
    };
    usb.host.devices = {
      svse5 = { };
      gmmk.enable = false;
      hori.enable = false;
      xpad.enable = false;
      nagatrinity.enable = false;
      shift.enable = false;
    };
    netdevs = {
      hostnet0.settings = {
        type = "bridge";
        br = "br";
        helper = "${nixosConfig.security.wrapperDir}/${nixosConfig.security.wrappers.qemu-bridge-helper.program}";
      };
      smbnet0.settings = {
        type = "user";
        restrict = "yes";
        net = "10.1.2.0/24";
        host = "10.1.2.1";
        smb = config.state.path + "/smb";
        smbserver = "10.1.2.2";
      };
      natnet0.settings = {
        type = "user";
        net = "10.1.3.0/24";
        host = "10.1.3.1";
      };
    };
  };
}
