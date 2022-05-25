{ meta, tf, config, pkgs, lib, ... }: with lib; let
  inherit (config.networking) domains;
in {
  imports = [
    ./matrix-synapse.nix
    ./vaultwarden.nix
    ./taskserver.nix
    ./prosody.nix
  ];

  options.home = {
    profileSettings.gensokyo.frontpage = mkOption {
      type = types.bool;
      default = false;
    };
  };

  config = {
    deploy.tf = let
      inherit (config.home.profileSettings.gensokyo) zone;
      domain = removeSuffix zone "${config.networking.hostName}.${config.networking.domain}";
    in {
      dns.records = mkIf (zone != null) {
        local_a = mkIf config.deploy.network.local.hasIpv4 {
          inherit zone domain;
          a.address = config.deploy.network.local.ipv4;
        };
        local_aaaa = mkIf (config.networking.enableIPv6 && config.deploy.network.local.hasIpv6) {
          inherit zone domain;
          aaaa.address = config.deploy.network.local.ipv6;
        };
        wan_a = {
          inherit zone;
          domain = config.networking.hostName;
          a.address = if config.deploy.network.wan.hasIpv4
            then config.deploy.network.wan.ipv4
            else tf.resources.wan_a_lookup.refAttr "addrs[0]";
        };
        wan_aaaa = mkIf (config.networking.enableIPv6 && config.deploy.network.wan.hasIpv6) {
          inherit zone;
          domain = config.networking.hostName;
          aaaa.address = config.deploy.network.wan.ipv6;
        };
        ygg = mkIf config.services.yggdrasil.enable {
          inherit zone;
          domain = "${config.networking.hostName}.y";
          aaaa.address = config.services.yggdrasil.address;
        };
      };
      resources = {
        wan_a_lookup = mkIf (zone != null && !config.deploy.network.wan.hasIpv4) {
          provider = "dns";
          type = "a_record_set";
          dataSource = true;
          inputs = {
            host = config.networking.domain;
          };
        };
      };
    };
    services = {
      # common service configs and defaults
      gitolite = {
        enableGitAnnex = mkDefault true;
        #adminPubkey = config.secrets.files.ssh_key.getAttr "public_key_openssh";
      };
      nginx = {
        package = mkDefault pkgs.nginxMainline;
        recommendedGzipSettings = mkDefault true;
        recommendedOptimisation = mkDefault true;
        recommendedProxySettings = mkDefault true;
        recommendedTlsSettings = mkDefault true;
      };
      bitlbee = {
        plugins = with pkgs; [ bitlbee-discord bitlbee-steam ];
        libpurple_plugins = mkDefault pkgs.purple-plugins-arc;
        authMode = mkDefault "Registered";
      };
      nginx.virtualHosts = mkIf config.home.profileSettings.gensokyo.frontpage {
        ${domains.frontpage.key} = {
          default = true;
          locations."/" = {
            return = "307 http://sator.in";
          };
          # TODO: hacking around duplicate listeners
          listen = mkForce (mapAttrsToList (_: binding: binding.nginx.out.listen) domains.frontpage.bindings);
        };
      };
    };
    networking.domains.frontpage = {
      enable = config.home.profileSettings.gensokyo.frontpage;
      nginx.extraParameters = [ "reuseport" "deferred" ];
    };
  };
}
