{ pkgs, config, lib, ... }: with lib; {
  options = {
    home.profiles.personal = lib.mkEnableOption "used as a day-to-day personal system";
  };

  config = mkIf config.home.profiles.personal {
    boot.kernel.sysctl = {
      "kernel.unprivileged_userns_clone" = "1";
    };

    # allow wheel to do things without password
    security.polkit.extraConfig = ''
      polkit.addRule(function(action, subject) {
        if (subject.isInGroup("wheel")) {
          return polkit.Result.YES;
        }
      });
    '';
    environment.systemPackages = with pkgs; [
      libimobiledevice
      hdparm
      smartmontools
      gptfdisk
      efibootmgr
      ntfs3g
      config.boot.kernelPackages.cpupower
      gdb
      strace
    ];

    services.locate = {
      enable = true;
      interval = "05:00";
    };
    services.physlock.enable = true;
    security.sudo.extraRules = mkAfter [
      { commands = [ { command = "ALL"; options = ["NOPASSWD"]; } ]; groups = [ "wheel" ]; }
    ];
    systemd.services.dev-hugepages.wantedBy = ["sysinit.target"];
    systemd.services.dev-hugepages1G.wantedBy = ["sysinit.target"];
  };
}
