{ pkgs, config, lib, ... }: with lib; let
  cfg = config.networking.nftables;
  inherit (config.networking) firewall;
  mapInterface = interface: let
    mapPort = type: port: { inherit type port; };
  in map (mapPort "tcp") interface.allowedTCPPorts
  ++ map (mapPort "tcp") interface.allowedTCPPortRanges
  ++ map (mapPort "udp") interface.allowedUDPPorts
  ++ map (mapPort "udp") interface.allowedUDPPortRanges;
  nfallow = { type, port }: let
    ports = if isInt port then toString port else "${toString port.from}-${toString port.to}";
  in ''${type} dport ${ports} accept'';
  allowed = mapInterface firewall;
  nftables-ports = pkgs.writeText "nftables-ports.conf" ''
    table inet filter {
      chain input_ports {
        ${concatMapStringsSep "\n" nfallow allowed}
      }
    }
  '';
in {
  networking = {
    firewall.enable = mkDefault false;
    nftables = {
      enable = true;
      ruleset = mkMerge [
        (mkBefore ''
          include "${./nftables.conf}"
        '')
        (mkIf config.services.yggdrasil.enable ''
          define yggdrasil_peer_listen_tcp = ${last (splitString ":" (head config.services.yggdrasil.listen))}
          include "${./yggdrasil.conf}"
        '')
        ''
          include "${nftables-ports}"
        ''
        (mkIf config.services.yggdrasil.enable (mkAfter ''
          table inet filter {
            chain input_ports {
              jump input_ports_yggdrasil
            }
          }
        ''))
      ];
    };
  };
}
