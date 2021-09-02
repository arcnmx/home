{ meta, tf, name, pkgs, config, lib, ... }: with lib; let
  freeform_tags = {
    inherit (meta.deploy) idTag;
    host = config.networking.hostName;
  };
  inherit (config.deploy.tf.import) common;
  inherit (tf.lib.tf) terraformExpr;
  compartment_id = common.resources.oci_homedeploy_compartment.importAttr "id";
  addr_ipv6 = terraformExpr ''cidrhost("${common.resources.oci_homedeploy_subnet.importAttr "ipv6cidr_block"}", 9)'';
  addr_ipv6_nix = let
    prefix = head (splitString "/" (common.resources.oci_homedeploy_subnet.importAttr "ipv6cidr_block"));
  in assert hasSuffix "::" prefix; prefix + "9";
  addr_ipv4_private = terraformExpr ''cidrhost("${common.resources.oci_homedeploy_subnet.importAttr "cidr_block"}", 7)'';
in {
  options.home = {
    profiles.host.cirno = mkEnableOption "hostname: cirno";
  };

  config = mkIf config.home.profiles.host.cirno {
    home.profiles.trusted = true;
    home.profiles.host.gensokyo = true;

    nixpkgs.localSystem = systems.examples.aarch64-multiplatform // {
      system = "aarch64-linux";
    };

    networking = {
      enableIPv6 = true;
      useNetworkd = true;
      useDHCP = false;
      interfaces.enp0s3 = {
        # NOTE: it's ens3 on amd machines fyi
        useDHCP = true;
        ipv6 = {
          addresses = [
            {
              address = addr_ipv6_nix;
              prefixLength = 64;
            }
          ];
          routes = [
            {
              address = "::";
              prefixLength = 0;
            }
          ];
        };
      };
    };
    deploy.network = {
      local.ipv4 = null;
      local.hasIpv6 = false;
      wan = {
        ipv4 = tf.resources.server.refAttr "public_ip";
        hasIpv4 = true;
        ipv6 = addr_ipv6;
        hasIpv6 = true;
      };
    };

    home-manager.users.root.services.sshd.authorizedKeys = singleton "${removeSuffix "\n" (tf.resources.ssh_home.getAttr "public_key_openssh")} home-deploy";
    deploy.tf = {
      imports = [ "common" ];
      deploy.systems.${name} = {
        connection = tf.resources.server.connection.set;
        triggers.common.server = tf.resources.server.refAttr "id";
        lustrate.enable = true;
      };
      resources = mkMerge [ {
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
          type = "file";
          inputs = {
            sensitive_content = tf.resources.ssh_home.refAttr "private_key_pem";
            filename = toString (tf.terraform.dataDir + "/ssh_home_cirno");
            file_permission = "0600";
          };
        };
        cloudinit = {
          provider = "cloudinit";
          type = "config";
          dataSource = true;
          inputs = {
            part = singleton {
              content_type = "text/cloud-config";
              content = "#cloud-config\n" + builtins.toJSON {
                disable_root = false;
              };
            };
          };
        };
        availability_domain = {
          provider = "oci";
          type = "identity_availability_domain";
          dataSource = true;
          inputs = {
            inherit compartment_id;
            ad_number = 1;
          };
        };
        generic_image = {
          provider = "oci";
          type = "core_images";
          dataSource = true;
          inputs = {
            inherit compartment_id;
            inherit (tf.resources.server.inputs) shape;
            operating_system = "Canonical Ubuntu"; # "Oracle Linux"
            sort_by = "TIMECREATED";
            sort_order = "DESC";
          };
        };
        server = {
          provider = "oci";
          type = "core_instance";
          inputs = {
            inherit compartment_id freeform_tags;
            extended_metadata = { };
            metadata = {
              ssh_authorized_keys = tf.resources.ssh_home.refAttr "public_key_openssh";
              user_data = tf.resources.cloudinit.refAttr "rendered";
            };
            shape = "VM.Standard.A1.Flex";
            shape_config = {
              memory_in_gbs = 24; # up to 24GB free
              ocpus = 4; # up to 4 free
            };
            source_details = {
              source_type = "image";
              source_id = tf.resources.generic_image.refAttr "images[0].id";
              boot_volume_size_in_gbs = 100; # min 50GB, up to 200GB free
            };
            create_vnic_details = [
              {
                assign_public_ip = true;
                hostname_label = config.networking.hostName;
                inherit freeform_tags;
                subnet_id = common.resources.oci_homedeploy_subnet.importAttr "id";
                private_ip = addr_ipv4_private;
                nsg_ids = [
                  (tf.resources.firewall_group.refAttr "id")
                ];
              }
            ];
            availability_domain = tf.resources.availability_domain.refAttr "name";
          };
          lifecycle.ignoreChanges = [
            "source_details[0].source_id"
          ];
          connection = {
            type = "ssh";
            user = "root";
            host = tf.lib.tf.terraformSelf "public_ip";
            timeout = "5m";
            ssh = {
              privateKey = tf.resources.ssh_home.refAttr "private_key_pem";
              privateKeyFile = tf.resources.ssh_home_file.refAttr "filename";
            };
          };
        };
        server_vnic = {
          provider = "oci";
          type = "core_vnic_attachments";
          dataSource = true;
          inputs = {
            inherit compartment_id;
            instance_id = tf.resources.server.refAttr "id";
          };
        };
        server_ipv6 = {
          provider = "oci";
          type = "core_ipv6";
          inputs = {
            vnic_id = tf.resources.server_vnic.refAttr "vnic_attachments[0].vnic_id";
            display_name = config.networking.hostName;
            ip_address = addr_ipv6;
            inherit freeform_tags;
          };
        };
        firewall_group = {
          provider = "oci";
          type = "core_network_security_group";
          inputs = {
            display_name = "${config.networking.hostName} firewall group";
            inherit compartment_id freeform_tags;
            vcn_id = common.resources.oci_vcn.importAttr "id";
          };
        };
      } (let
        inherit (config.networking) firewall;
        ipv4 = "0.0.0.0/0";
        ipv6 = "::/0";
        tcp = 6;
        udp = 17;
        mapPort = source: protocol: port: {
          provider = "oci";
          type = "core_network_security_group_security_rule";
          inputs = {
            network_security_group_id = tf.resources.firewall_group.refAttr "id";
            inherit protocol source;
            direction = "INGRESS";
            ${if protocol == tcp then "tcp_options" else "udp_options"} = {
              destination_port_range = if isAttrs port then {
                min = port.from;
                max = port.to;
              } else {
                min = port;
                max = port;
              };
            };
          };
        };
        mapAll = protocol: port: [ (mapPort ipv4 protocol port) (mapPort ipv6 protocol port) ];
        rules = concatLists (
          map (mapAll tcp) (unique firewall.allowedTCPPorts)
          ++ map (mapAll tcp) firewall.allowedTCPPortRanges
          ++ map (mapAll udp) (unique firewall.allowedUDPPorts)
          ++ map (mapAll udp) firewall.allowedUDPPortRanges
        ); # TODO: use `count` and index into a fancy json or something?
      in listToAttrs (imap0 (i: rule: nameValuePair "firewall${toString i}" rule) rules)) ];
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
      #gitolite.enable = true;
      #bitlbee.enable = true;
      prosody.enable = true;
      taskserver.enable = true;
      vaultwarden.enable = true;
      nginx.enable = true;
      postgresql.enable = true;
      matrix-synapse.enable = true;
      matrix-appservices = {
        mautrix-hangouts.enable = true;
        mx-puppet-discord.enable = true;
        mautrix-whatsapp.enable = true;
        #matrix-appservice-irc.enable = true;
      };
    };
    home.profileSettings.gensokyo.frontpage = true;
  };
}
