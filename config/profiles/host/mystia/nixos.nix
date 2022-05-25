{ meta, tf, name, pkgs, config, lib, ... }: with lib; {
  imports = [
    ../../../../cfg/trusted.nix
  ];

  config = {
    networking = {
      enableIPv6 = false;
      useNetworkd = true;
      useDHCP = false;
      interfaces.ens3 = {
        useDHCP = true;
      };
    };
    deploy.network = {
      local.ipv4 = null;
      wan = {
        ipv4 = tf.resources.server.refAttr "ipv4_address";
        hasIpv4 = true;
      };
    };

    home-manager.users.root.services.sshd.authorizedKeys = singleton "${tf.resources.ssh_home.getAttr "public_key_openssh"} home-deploy";
    deploy.tf = {
      imports = [ "common" ];
      deploy.systems.${name} = {
        connection = tf.resources.server.connection.set;
        triggers.copy.server = tf.resources.server.refAttr "id";
      };
      resources = {
        ssh_home = {
          provider = "tls";
          type = "private_key";
          inputs = {
            algorithm = "RSA";
            rsa_bits = 2048;
          };
        };
        ssh_home_file = {
          provider = "local";
          type = "sensitive_file";
          inputs = {
            content = tf.resources.ssh_home.refAttr "private_key_pem";
            filename = toString (tf.terraform.dataDir + "/ssh_home_mystia");
            file_permission = "0600";
          };
        };
        image = {
          provider = "digitalocean";
          type = "image";
          dataSource = true;
          inputs = {
            name = "nixos-unstable-2020-09-30-84d74ae9c9cb"; # nixos-unstable-small from 2019-07-06
          };
        };
        server_ssh_home = {
          provider = "digitalocean";
          type = "ssh_key";
          inputs = {
            name = "${meta.deploy.idTag}/${config.networking.hostName}";
            public_key = tf.resources.ssh_home.refAttr "public_key_openssh";
          };
        };
        server = {
          provider = "digitalocean";
          type = "droplet";
          inputs = {
            image = tf.resources.image.refAttr "image";
            name = "${config.networking.hostName}.${config.networking.domain}";
            region = "tor1";
            #region = "sfo2";
            size = "s-1vcpu-2gb";
            #resize_disk = false; # set to temporarily upgrade
            #monitoring = true; # forces replacement :<
            #ipv6 = true;
            ssh_keys = [
              (tf.resources.server_ssh_home.refAttr "id")
            ];
            tags = singleton meta.deploy.idTag;
          };
          connection = {
            type = "ssh";
            user = "root";
            host = tf.lib.tf.terraformSelf "ipv4_address";
            timeout = "2m";
            ssh = {
              privateKey = tf.resources.ssh_home.refAttr "private_key_pem";
              privateKeyFile = tf.resources.ssh_home_file.refAttr "filename";
            };
          };
          provisioners = [ {
            type = "remote-exec";
            remote-exec.inline = [
              "dd if=/dev/zero of=/swaptemp bs=1M count=1024"
              "chmod 0600 /swaptemp"
              "mkswap /swaptemp"
              "swapon /swaptemp"
            ];
          } ];
        };
      };
    };

    nix.gc = {
      automatic = true;
      options = "-d"; # actually delete old things
    };

    swapDevices = [ {
      device = "/swap";
      size = 2048;
      randomEncryption.enable = true;
    } ];
    systemd.services.mkswap-swap = let
      dev = "dev-loop-control.device";
    in {
      wants = [ dev ];
      after = [ dev ];
    };
    services = {
      udev.extraRules = ''
        SUBSYSTEM=="misc", DEVNAME="/dev/loop-control", TAG+="systemd"
      '';
    };
    systemd.services.matrix-synapse.environment = {
      # default is 0.5; see https://github.com/matrix-org/synapse#help-synapse-is-slow-and-eats-all-my-ramcpu
      SYNAPSE_CACHE_FACTOR = "0.25";
    };
    system.stateVersion = "19.09";
  };
}
