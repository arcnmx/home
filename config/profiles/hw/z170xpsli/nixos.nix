{ config, pkgs, lib, ... }: with lib; {
  options = {
    home.profiles.hw.z170xpsli = mkEnableOption "GIGABYTE Z170 XP SLI";
  };

  config = mkIf config.home.profiles.hw.z170xpsli {
    home.profiles.hw.intel = true;

    systemd.network.links.eth = {
      matchConfig = {
        MACAddress = "1c:1b:0d:06:22:d3";
      };
      linkConfig = {
        Name = "eth";
      };
    };
    systemd.network.netdevs.br = {
      netdevConfig = {
        Name = "br";
        Kind = "bridge";
        MACAddress = "1c:1b:0d:06:22:d3";
      };
    };
  };
}
