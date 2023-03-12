{ meta, target, tf, pkgs, config, lib, ... }: with lib; let
  cfg = config.services.tailscale;
  StateDirectory = "tailscale";
  loginState = "/var/lib/${StateDirectory}/login";
  enable = cfg.enable && cfg.login.enable;
  ownDevices = attrValues (filterAttrs (_: dev:
    dev.shortName == config.networking.hostName
    && elem dev.user meta.network.tailscale.users
  ) meta.network.tailscale.devices);
  otherDevices = filterAttrs (_: dev:
    dev.shortName != config.networking.hostName
    && dev.isPersonalDevice
  ) meta.network.tailscale.devices;
in {
  options = {
    services.tailscale = {
      trust = mkOption {
        type = types.bool;
        default = false;
      };
      device = mkOption {
        type = types.nullOr types.attrs;
        default = if ownDevices != [ ]
          then head ownDevices
          else null;
      };
      login = {
        enable = mkEnableOption "enroll";
        authorized = mkOption {
          type = types.bool;
          default = config.deploy.personal.enable;
        };
      };
    };
  };
  config = mkMerge [
    {
      services.tailscale = {
        enable = mkDefault config.deploy.personal.enable;
        permitCertUid = mkDefault (mapNullable toString config.users.users.arc.uid);
        interfaceName = mkDefault "tailscale";
      };
    }
    (mkIf cfg.enable {
      systemd.services.tailscaled = {
        after = mkIf config.services.connman.enable [ "connman.service" ];
        serviceConfig = {
          # filter out noisy connection status logs
          LogLevelMax = "notice";
        };
      };
      systemd.network.wait-online.ignoredInterfaces = [ cfg.interfaceName ];
      networking.firewall = {
        allowedUDPPorts = [
          cfg.port
          3478 # STUN
        ];
        trustedInterfaces = mkIf cfg.trust [ cfg.interfaceName ];
      };
      networking.hosts = listToAttrs (concatMap (dev:
        map (addr: nameValuePair addr [ dev.shortName ]) dev.addresses
      ) (attrValues otherDevices));
    })
    (mkIf (cfg.enable && cfg.login.enable) {
      systemd.services.login-tailscale = rec {
        wants = [ "network-online.target" ];
        wantedBy = [ "tailscaled.service" ];
        after = wantedBy ++ wants;
        unitConfig = {
          ConditionPathExists = "!${loginState}";
        };
        serviceConfig = {
          inherit StateDirectory;
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = ''${cfg.package}/bin/tailscale up --auth-key file:${config.secrets.files.tailnet-activation.path}'';
          ExecStartPost = ''${pkgs.coreutils}/bin/touch ${loginState}'';
          TimeoutSec = 60;
        };
      };
      secrets.files.tailnet-activation = {
        text = tf.resources.tailnet-activation.refAttr "key";
      };
      deploy.tf.resources = {
        tailnet-activation = {
          provider = "tailscale";
          type = "tailnet_key";
          inputs = {
            reusable = false;
            preauthorized = cfg.login.authorized;
          };
          lifecycle.ignoreChanges = "all";
          connection = tf.deploy.systems.${config.networking.hostName}.connection.set;
          provisioners = singleton {
            when = "destroy";
            remote-exec.command = ''
              tailscale logout || true
              rm -f ${loginState}
            '';
          };
        };
        tailnet-properties = {
          enable = cfg.device != null;
          provider = "tailscale";
          type = "device_key";
          inputs = {
            device_id = cfg.device.id;
            key_expiry_disabled = true;
          };
        };
      };
    })
  ];
}
