{ config, pkgs, lib, ... }: with lib; {
  options = {
    home.profiles.hw.1700 = mkEnableOption "AMD Ryzen R7 1700";
  };

  config = mkIf config.home.profiles.hw.1700 {
    systemd.services.cpuclock = {
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.zenstates}/bin/zenstates -p 0 -f 9e -d 8 -v 1e";
      };
      wantedBy = ["multi-user.target"];
    };
  };
}
