{ nixosConfig, config, trusted, lib, ... }: with lib; let
  inherit (nixosConfig.hardware.vfio) disks;
in {
  imports = [
    ./common.nix ./scream.nix ./virtio.nix
    ./windows-q35.nix
    ./vfio.nix
  ] ++ trusted.import.nixos "vfio/machines/goliath";
  config = {
    systemd.wants = [
      (mkIf config.disks.games-adata.enable disks.cow.windows-games-adata-kat.systemd.id)
    ];
    enable = true;
    name = "goliath";
    state.owner = "kat";
    virtio.enable = true;
    memory.sizeMB = 8 * 1024;
    smp = {
      settings = {
        threads = 1;
        cores = 6;
      };
      pinning.coreOffset = 8;
    };
    disks = {
      windows = {
        scsi.lun = 0;
        path = "/dev/disk/by-partlabel/windows-kat";
      };
      games-adata = {
        scsi.lun = 1;
        inherit (disks.cow.windows-games-adata-kat) path;
      };
    };
    usb.host.devices = {
      nighthawk-x8 = { };
      naga2014 = { };
      arctis7p-plus = { };
      hori.enable = false;
      xpad = { };
      nagatrinity.enable = false;
      gmmk.enable = false;
      shift.enable = false;
      yubikey5-kat = { };
      yubikey5c-kat.enable = false;
    };
    scream = {
      mode = "ip";
      ip = {
        mode = "unicast";
        port = 4011;
      };
    };
    netdevs = {
      hostnet0.settings = {
        type = "bridge";
        br = "br";
        helper = "${nixosConfig.security.wrapperDir}/${nixosConfig.security.wrappers.qemu-bridge-helper.program}";
      };
      natnet0.settings = {
        type = "user";
        net = "10.1.4.0/24";
        host = "10.1.4.1";
      };
      smbnet0.settings = {
        type = "user";
        restrict = "yes";
        net = "10.1.5.0/24";
        host = "10.1.5.1";
        smb = config.state.path + "/smb";
        smbserver = "10.1.5.2";
      };
    };
  };
}
