{ lib, config, pkgs, ... }: with lib; let
  cfg = config.hardware.vfio;
  nixosConfig = config;
  systemd2mqtt = config.services.systemd2mqtt;
  hmp = machineConfig: cmd: if machineConfig.qemucomm.enable
    then "${getExe machineConfig.exec.qmp} hmp ${escapeShellArg cmd}"
    else "echo ${escapeShellArg cmd} | ${getExe machineConfig.exec.monitor}";
  systemdUnits' =
    concatLists (mapAttrsToList (_: dev: [
      dev.vfio dev.bind
      dev.gpu.nvidia.drain dev.gpu.nvidia.persist
    ]) cfg.devices)
    ++ mapAttrsToList (_: disk: disk.systemd) cfg.disks.mapped
    ++ mapAttrsToList (_: disk: disk.systemd) cfg.disks.cow
    ++ concatLists (mapAttrsToList
      (_: machine: mapAttrsToList (_: dev: dev.systemd) machine.hotplug.devices)
      (filterAttrs (_: m: m.enable && m.hotplug.enable) cfg.qemu.machines)
    )
    ++ mapAttrsToList (_: machine: machine.scream.systemd) (filterAttrs (_: m: m.scream.systemd.enable) cfg.qemu.machines)
    ++ mapAttrsToList (_: machine: machine.systemd) (filterAttrs (_: m: m.enable && m.systemd.enable) cfg.qemu.machines);
  systemdUnits = filter (service: service.enable) systemdUnits';
  applyPermission = { permission, path }: let
    owner = optionalString (permission.owner != null) permission.owner;
    group = optionalString (permission.group != null) permission.group;
    chown = ''chown ${owner}:${group} ${path}'';
    chmod = ''chmod ${permission.mode} ${path}'';
    cmds = optional (permission.owner != null || permission.group != null) chown
    ++ optional (permission.mode != null) chmod;
  in concatStringsSep "\n" cmds;
  polkitPermissions = systemd: {
    ${systemd.polkit.user} = {
      systemd.units = [ systemd.id ];
    };
  };
  mqttUnits = systemd: mkIf systemd.mqtt.enable [
    systemd.id
  ];
  systemdService = systemd: {
    ${systemd.name} = unmerged.merge systemd.unit;
  };
  udevPermission = permission:
    optional (permission.owner != null) ''OWNER="${permission.owner}"''
    ++ optional (permission.group != null) ''GROUP="${permission.group}"''
    ++ optional (permission.mode != null) ''MODE="${permission.mode}"'';
  reserve-pci-driver = pkgs.writeShellScript "reserve-pci.sh" ''
    printf '%s\n' "$1" > /sys/bus/pci/devices/$2/driver_override
  '';
  permissionType = types.submodule ({ config, ... }: {
    options = {
      enable = mkEnableOption "permissions" // {
        default = config.owner != null || config.group != null || config.mode != null;
      };
      owner = mkOption {
        type = with types; nullOr str;
        default = null;
      };
      group = mkOption {
        type = with types; nullOr str;
        default = null;
      };
      mode = mkOption {
        type = with types; nullOr str;
        default = null;
      };
    };
  });
  systemdModule = { config, ... }: {
    options = {
      enable = mkEnableOption "systemd service" // {
        default = true;
      };
      mqtt.enable = mkEnableOption "systemd2mqtt control" // {
        default = true;
      };
      name = mkOption {
        type = types.str;
      };
      id = mkOption {
        type = types.str;
        default = config.name + ".service";
      };
      depends = mkOption {
        type = with types; listOf str;
        default = [ ];
      };
      wants = mkOption {
        type = with types; listOf str;
        default = [ ];
      };
      user = mkOption {
        type = with types; nullOr str;
        default = null;
      };
      polkit.user = mkOption {
        type = with types; nullOr str;
        default = config.user;
      };
      type = mkOption {
        type = types.str;
        default = "oneshot";
      };
      script = mkOption {
        type = types.lines;
        default = "";
      };
      unit = mkOption {
        type = unmerged.type;
      };
    };
    config = {
      unit = {
        inherit (config) enable;
        path = [ pkgs.coreutils ];
        after = mkIf (config.depends != [ ] || config.wants != [ ]) (config.depends ++ config.wants);
        requires = mkIf (config.depends != [ ]) config.depends;
        wants = mkIf (config.wants != [ ]) config.wants;
        script = mkIf (config.script != "") config.script;
        restartIfChanged = mkDefault false;
        serviceConfig = {
          User = mkIf (config.user != null) (mkDefault config.user);
          Type = mkDefault config.type;
          RemainAfterExit = mkIf (config.type == "oneshot") (mkDefault true);
          TimeoutSec = mkIf (config.type == "oneshot") (mkDefault 180);
        };
      };
    };
  };
  mapDiskModule = { name, config, ... }: {
    options = {
      name = mkOption {
        type = types.str;
        default = name;
      };
      path = mkOption {
        type = types.path;
      };
      uuid = mkOption {
        type = types.nullOr types.str;
        default = null;
      };
      minor = mkOption {
        type = types.nullOr types.int;
        default = null;
      };
      flags = mkOption {
        type = types.enum [ null "ro" "rw" ];
        default = null;
      };
      concise = mkOption {
        type = types.str;
        default = "${config.name},${toString config.uuid},${toString config.minor},${toString config.flags}";
      };
      source = mkOption {
        type = types.path;
      };
      permission = mkOption {
        type = permissionType;
        default = { };
      };
      mbr = {
        id = mkOption {
          type = types.strMatching "[0-9a-f]{8}";
          default = substring 8 8 (builtins.hashString "sha256" config.name);
        };
        partType = mkOption {
          type = types.int;
          default = 7; # NTFS
        };
      };
      systemd = mkOption {
        type = types.submodule systemdModule;
        default = { };
      };
    };
    config = {
      path = "/dev/mapper/${config.name}";
      systemd = {
        name = "vfio-mapdisk-${config.name}";
        mqtt.enable = mkDefault false;
        polkit.user = config.permission.owner;
        script = ''
          ${nixosConfig.lib.arc-vfio.map-disk}/bin/map-disk ${config.source} ${escapeShellArg config.concise} ${config.mbr.id} ${toString config.mbr.partType}
          ${applyPermission {
            inherit (config) permission path;
          }}
        '';
        unit.serviceConfig = {
          RuntimeDirectory = config.systemd.name;
          ExecStop = "${nixosConfig.lib.arc-vfio.map-disk}/bin/map-disk STOP";
        };
      };
    };
  };
  snapshotDiskModule = { name, config, ... }: {
    options = {
      name = mkOption {
        type = types.str;
        default = name;
      };
      path = mkOption {
        type = types.path;
      };
      source = mkOption {
        type = types.path;
      };
      permission = mkOption {
        type = permissionType;
        default = { };
      };
      mode = mkOption {
        type = types.enum [ "P" "N" ];
        default = "N";
        description = "(P)ersistent snapshot?";
      };
      storage = mkOption {
        type = types.path;
      };
      sizeMB = mkOption {
        type = types.int;
        default = 1024 * 8;
      };
      systemd = mkOption {
        type = types.submodule systemdModule;
        default = { };
      };
    };
    config = {
      path = "/dev/mapper/${config.name}";
      storage = mkIf (config.mode == "N") (mkOptionDefault "/tmp/qemu-cow-${config.name}");
      systemd = {
        name = "vfio-cowdisk-${config.name}";
        mqtt.enable = mkDefault false;
        polkit.user = config.permission.owner;
        script = ''
          ${nixosConfig.lib.arc-vfio.cow-disk}/bin/cow-disk ${config.source} ${config.name} ${config.mode} ${config.storage} ${toString config.sizeMB}
          ${applyPermission {
            inherit (config) permission path;
          }}
        '';
        unit.serviceConfig = {
          RuntimeDirectory = config.systemd.name;
          ExecStop = "${nixosConfig.lib.arc-vfio.cow-disk}/bin/cow-disk STOP";
        };
      };
    };
  };
  vfioDeviceModule = let
    canRun = pkgs.writeShellScriptBin "service-precondition" ''
      SERVICE="$1"
      if ${systemctl} is-active "$SERVICE" > /dev/null; then
        echo "conflicting service "$SERVICE" is running" >&2
        exit 1
      fi
    '';
    bindStop = pkgs.writeShellScriptBin "pci-bind-stop" ''
      DRIVER="$1"
      HOST="$2"
      if [[ -L /sys/bus/pci/drivers/$DRIVER/$HOST ]]; then
        echo $HOST > /sys/bus/pci/drivers/$DRIVER/unbind
      fi
    '';
    systemctl = "${config.systemd.package}/bin/systemctl";
    smi = "${config.hardware.nvidia.package.bin}/bin/nvidia-smi";
    smiValue = value:
      if value == true then "1"
      else if value == false then "0"
      else if isList value then concatMapStringsSep "," smiValue value
      else toString value;
  in { config, name, ... }: {
    options = {
      enable = mkEnableOption "VFIO device";
      reserve = mkEnableOption "VFIO reserve";
      vendor = mkOption {
        type = types.strMatching "[0-9a-f]{4}";
      };
      product = mkOption {
        type = types.strMatching "[0-9a-f]{4}";
      };
      subvendor = mkOption {
        type = types.nullOr (types.strMatching "[0-9a-f]{4}");
        default = null;
      };
      subproduct = mkOption {
        type = types.nullOr (types.strMatching "[0-9a-f]{4}");
        default = null;
      };
      unbindVts = mkEnableOption "unbind-vts";
      host = mkOption {
        type = with types; nullOr str;
        default = null;
        example = "02:00.0";
      };
      driver = mkOption {
        type = with types; nullOr str;
        default = null;
      };
      vfio = mkOption {
        type = types.submodule systemdModule;
        default = { };
      };
      bind = mkOption {
        type = types.submodule systemdModule;
        default = { };
      };
      udev.rule = mkOption {
        type = types.separatedString ", ";
      };
      softConflicts = mkOption {
        type = types.bool;
        default = config.gpu.enable && config.gpu.primary;
      };
      gpu = {
        enable = mkEnableOption "GPU" // {
          default = elem config.driver [ "nvidia" "amdgpu" ];
        };
        primary = mkOption {
          type = types.bool;
          default = false;
        };
        nvidia = {
          enable = mkEnableOption "NVIDIA GPU" // {
            default = config.driver == "nvidia";
          };
          uuid = mkOption {
            type = with types; nullOr (strMatching "GPU-[-0-9a-f]*");
            default = null;
          };
          settings = mkOption {
            type = with types; attrsOf (oneOf [ int bool (listOf int) ]);
            default = { };
          };
          drain = mkOption {
            type = types.submodule systemdModule;
            default = { };
          };
          persist = mkOption {
            type = types.submodule systemdModule;
            default = { };
          };
        };
      };
    };
    config = {
      vfio = {
        name = "pci-${name}-vfio";
        mqtt.enable = mkDefault false;
        script = mkMerge (
          optional config.unbindVts "${nixosConfig.lib.arc-vfio.unbind-vts}/bin/unbind-vts"
          ++ singleton "${nixosConfig.lib.arc-vfio.reserve-pci}/bin/reserve-pci ${if config.host != null then config.host else "${config.vendor}:${config.product}"}"
        );
        unit = {
          wantedBy = mkIf (config.enable && config.reserve) [ "multi-user.target" ];
          conflicts = mkIf config.gpu.primary [ "graphical.target" ];
          after = mkIf config.gpu.primary [ "display-manager.service" ];
          before = mkIf config.gpu.nvidia.enable [ "nvidia-x11.service" ];
          serviceConfig = {
            RuntimeDirectory = config.vfio.name;
            ExecStartPre = mkIf config.bind.enable [ "${systemctl} stop ${config.bind.id}" ];
            ExecStop = "${nixosConfig.lib.arc-vfio.reserve-pci}/bin/reserve-pci STOP";
          };
        };
      };
      bind = {
        name = "pci-${name}-bind";
        enable = mkDefault (config.driver != null && config.host != null);
        mqtt.enable = mkDefault false;
        unit = rec {
          wants = mkIf config.gpu.nvidia.enable [ "nvidia-x11.service" ];
          bindsTo = mkIf config.gpu.nvidia.enable [ "nvidia-x11.service" ];
          after = mkMerge [
            [ config.vfio.id ]
            (mkIf config.gpu.nvidia.enable [
              "nvidia-x11.service"
            ])
          ];
          conflicts = mkIf (!config.softConflicts) [ config.vfio.id ];
          script = mkMerge [ ''
            if [[ ! -L /sys/bus/pci/drivers/${config.driver}/${config.host} ]]; then
              echo > /sys/bus/pci/devices/${config.host}/driver_override
              echo ${config.host} > /sys/bus/pci/drivers/${config.driver}/bind
            fi
          '' (mkIf config.gpu.nvidia.enable (mkAfter ''
            ${smi} drain -p ${config.host} -m 0 || true
          '')) ];
          serviceConfig = {
            ExecStartPre = mkIf config.softConflicts [ "${getExe canRun} ${config.vfio.id}" ];
            ExecStop = [ "${getExe bindStop} ${config.driver} ${config.host}" ];
          };
        };
      };
      gpu.nvidia = {
        drain = {
          name = "pci-${name}-drain";
          enable = mkDefault config.gpu.nvidia.enable;
          mqtt.enable = mkDefault false;
          unit = rec {
            wantedBy = mkIf (config.gpu.nvidia.enable && !config.gpu.primary && !config.reserve) [ "nvidia-x11.service" ];
            requisite = [ config.bind.id "nvidia-x11.service" ];
            conflicts = [ config.vfio.id ];
            bindsTo = requisite;
            after = requisite ++ conflicts;
            serviceConfig = {
              ExecStart = [
                "${smi} drain -p ${config.host} -m 1"
              ];
              ExecStop = [
                "${smi} drain -p ${config.host} -m 0"
              ];
            };
          };
        };
        persist = {
          # NOTE: Persistence mode is deprecated and will be removed in a future release. Please use nvidia-persistenced instead.
          name = "pci-${name}-persist";
          enable = mkDefault config.gpu.nvidia.enable;
          mqtt.enable = mkDefault false;
          unit = rec {
            requires = [ config.bind.id "nvidia-x11.service" ];
            conflicts = [ config.vfio.id config.gpu.nvidia.drain.id ];
            bindsTo = requires;
            after = requires ++ conflicts;
            serviceConfig = {
              ExecStart = [
                "${smi} -i ${config.gpu.nvidia.uuid} --persistence-mode=1"
              ] ++ mapAttrsToList (flag: value:
                "${smi} -i ${config.gpu.nvidia.uuid} --${flag}=${escapeShellArg (smiValue value)}"
              ) config.gpu.nvidia.settings;
              ExecStop = [
                "${smi} -i ${config.gpu.nvidia.uuid} --persistence-mode=0"
              ];
            };
          };
        };
      };
      udev.rule = mkMerge [
        (mkBefore ''SUBSYSTEM=="pci"'')
        (mkBefore ''ACTION=="add"'')
        (mkIf (config.host != null) ''KERNEL=="${config.host}"'')
        ''ATTR{vendor}=="0x${config.vendor}"''
        ''ATTR{device}=="0x${config.product}"''
        (mkAfter ''RUN+="${reserve-pci-driver} vfio-pci %k"'')
      ];
    };
  };
  usbDeviceModule = { config, name, ... }: {
    options = {
      enable = mkEnableOption "USB device" // {
        default = true;
      };
      name = mkOption {
        type = types.str;
        default = name;
      };
      vendor = mkOption {
        type = types.strMatching "[0-9a-f]{4}";
      };
      product = mkOption {
        type = types.nullOr (types.strMatching "[0-9a-f]{4}");
        default = null;
      };
      permission = mkOption {
        type = permissionType;
        default = { };
      };
      udev = {
        enable = mkEnableOption "udev rule" // {
          default = config.permission.enable;
        };
        rule = mkOption {
          type = types.separatedString ", ";
        };
      };
    };
    config = {
      permission.group = mkDefault "plugdev";
      udev.rule = mkMerge ([
        (mkBefore ''SUBSYSTEM=="usb"'')
        (mkBefore ''ACTION=="add"'')
        ''ATTR{idVendor}=="${config.vendor}"''
        (mkIf (config.product != null) ''ATTR{idProduct}=="${config.product}"'')
      ] ++ (map mkAfter (udevPermission config.permission)));
    };
  };
  hotplugDeviceModule = machineName: machineConfig: { config, ... }: {
    options = {
      systemd = mkOption {
        type = types.submodule systemdModule;
        default = { };
      };
    };
    config = {
      systemd = {
        name = "vm-${machineName}-${config.id}";
        user = mkDefault machineConfig.systemd.user;
        unit = rec {
          requisite = mkIf machineConfig.systemd.enable [ machineConfig.systemd.id ];
          bindsTo = requisite;
          wantedBy = mkIf (machineConfig.systemd.enable && config.default) [ machineConfig.systemd.id ];
          after = requisite;
          conflicts = let
            otherMachines = filterAttrs (name: machine: machine.enable && machine.systemd.enable && name != machineName) cfg.qemu.machines;
            machineIds = mapAttrsToList (_: machine: let
              devices = attrValues machine.hotplug.devices;
              matching = filter (dev: dev.name == config.name) devices;
            in map (dev: dev.systemd.id) matching) otherMachines;
          in concatLists machineIds;
          serviceConfig = {
            ExecStart = if machineConfig.qemucomm.enable
              then "${getExe machineConfig.exec.qmp} --wait add-device ${escapeShellArgs config.out.addDeviceArgs}"
              else hmp machineConfig config.out.monitorLine;
            ExecStop = if machineConfig.qemucomm.enable
              then "${getExe machineConfig.exec.qmp} del-device --wait ${config.id}"
              else hmp machineConfig "device_del ${config.id}";
          };
        };
      };
    };
  };
  machineModule = { config, name, ... }: {
    options = {
      systemd = mkOption {
        type = types.submodule systemdModule;
        default = { };
      };
      hotplug.devices = mkOption {
        type = with types; attrsOf (submodule (hotplugDeviceModule name config));
      };
      scream = {
        playback = {
          user = mkOption {
            type = with types; nullOr str;
            default = null;
          };
          pulse = {
            server = mkOption {
              type = with types; nullOr str;
              default = null;
            };
          };
        };
        systemd = mkOption {
          type = types.submodule systemdModule;
          default = { };
        };
      };
    };
    config = let
      otherMachines = filterAttrs (n: _: n != name) cfg.qemu.machines;
      sameMachines = filterAttrs (_: machine: machine.enable && machine.systemd.enable && machine.name == config.name) otherMachines;
    in {
      systemd = {
        name = "vm-${name}";
        user = mkDefault config.state.owner;
        script = getExe config.exec.package;
        type = "exec";
        unit = let
          qga = getExe config.exec.qga;
          qgaShutdown = config.qga.enable && config.qemucomm.enable;
          ExecStop = optionalString qgaShutdown ''
            if ${pkgs.coreutils}/bin/timeout 1 ${qga} info > /dev/null; then
              ${qga} shutdown
            fi
          '' + optionalString config.qmp.enable ''
            if ${hmp config "system_powerdown"}; then
              ${pkgs.coreutils}/bin/sleep 3
              ${hmp config "system_powerdown"}
            fi
          '';
        in {
          conflicts = mapAttrsToList (_: machine: machine.systemd.id) sameMachines;
          serviceConfig = mkMerge [ {
            PIDFile = mkIf (config.exec.pidfile != null) config.exec.pidfile;
            StateDirectory = mkIf (hasPrefix "/var/lib/" config.state.path) (removePrefix "/var/lib/" config.state.path);
            RuntimeDirectory = mkIf (hasPrefix "/run/" config.state.runtimePath) (removePrefix "/run/" config.state.runtimePath);
            OOMScoreAdjust = -150;
            LogFilterPatterns = mkIf (versionAtLeast nixosConfig.systemd.package.version "253") [
              # reduce spam when pulse/pw needs a restart
              "~pulseaudio: Reason: Connection terminated"
              "~pa_threaded_mainloop_lock failed"
            ];
          } (mkIf (config.qmp.enable || qgaShutdown) {
            ExecStop = singleton (pkgs.writeShellScript "vm-${config.name}-stop" ExecStop);
            KillSignal = "SIGCONT"; # only signal if timeout occurs
            FinalKillSignal = "SIGTERM";
            TimeoutStopSec = "2m";
          }) ];
        };
      };
      scream = {
        playback.pulse.server = mkIf (config.scream.playback.user != null)
          (mkDefault "unix:/run/user/${toString nixosConfig.users.users.${config.scream.playback.user}.uid}/pulse/native");
        systemd = {
          name = "vm-${name}-scream";
          enable = config.enable && config.scream.enable;
          type = "exec";
          polkit.user = mkDefault config.systemd.polkit.user;
          unit = {
            wantedBy = mkIf (config.scream.mode == "ivshmem") [ config.systemd.id ];
            conflicts = mapAttrsToList (_: machine: machine.scream.systemd.id) (filterAttrs (_: machine: machine.scream.systemd.enable) sameMachines);
            after = mkIf (config.scream.mode == "ivshmem") [ config.systemd.id ];
            unitConfig = {
              ConditionPathExists = mkIf (
                config.scream.playback.backend == "pulse"
                && config.scream.playback.pulse.server != null
                && hasPrefix "unix:" config.scream.playback.pulse.server
              ) [
                (removePrefix "unix:" config.scream.playback.pulse.server)
              ];
            };
            environment = {
              PULSE_SERVER = mkIf (config.scream.playback.backend == "pulse" && config.scream.playback.pulse.server != null)
                  config.scream.playback.pulse.server;
              PULSE_COOKIE = mkIf (config.scream.playback.backend == "pulse" && config.scream.playback.user != null)
                "${nixosConfig.users.users.${config.scream.playback.user}.home}/.config/pulse/cookie";
            };
            serviceConfig = {
              ExecStart = singleton config.scream.playback.cli.command;
              ExecStartPre = mkIf (config.scream.mode == "ivshmem") [
                (pkgs.writeShellScript "${config.scream.systemd.name}-pre" ''
                  while [[ ! -e ${config.scream.ivshmem.path} ]]; do
                    sleep 1
                  done
                '')
              ];
            };
          };
        };
      };
      exec = {
        preExec = mkMerge [
          (mkIf (config.systemd.depends != [ ]) ''
            systemctl start ${toString config.systemd.depends}
          '')
          (mkIf (config.systemd.wants != [ ]) ''
            systemctl start ${toString config.systemd.wants} || true
          '')
        ];
      };
    };
  };
in {
  options.hardware.vfio = {
    devices = mkOption {
      type = with types; attrsOf (submodule vfioDeviceModule);
      default = { };
    };
    usb = {
      devices = mkOption {
        type = with types; attrsOf (submodule usbDeviceModule);
        default = { };
      };
    };
    disks = {
      mapped = mkOption {
        type = with types; attrsOf (submodule mapDiskModule);
        default = { };
      };
      cow = mkOption {
        type = with types; attrsOf (submodule snapshotDiskModule);
        default = { };
      };
    };
    qemu.machines = mkOption {
      type = with types; attrsOf (submoduleWith {
        modules = [ machineModule ];
      });
    };
  };
  config = {
    systemd.services = mkMerge (map systemdService systemdUnits ++ singleton {
      display-manager = rec {
        wants = mapAttrsToList (_: dev: dev.bind.id) (filterAttrs (_: dev: dev.gpu.enable && dev.gpu.primary) cfg.devices);
        bindsTo = wants;
        after = mapAttrsToList (_: dev: dev.bind.id) (filterAttrs (_: dev: dev.gpu.enable) cfg.devices);
      };
    });
    security.polkit.users = mkMerge (map polkitPermissions systemdUnits);
    services.systemd2mqtt.units = mkMerge (map mqttUnits systemdUnits);
    systemd.tmpfiles.rules = mkMerge (mapAttrsToList (_: machine: [
      "d ${machine.state.path} 0750 ${machine.state.owner} kvm -"
      "d ${machine.state.runtimePath} 0750 ${machine.state.owner} kvm -"
    ]) (filterAttrs (_: m: m.enable) cfg.qemu.machines));
    services.udev.extraRules = mkMerge (
      mapAttrsToList (_: usb: usb.udev.rule) (filterAttrs (_: usb: usb.enable && usb.udev.enable) cfg.usb.devices)
      ++ mapAttrsToList (_: dev: dev.udev.rule) (filterAttrs (_: dev: dev.reserve) cfg.devices)
    );
    boot.modprobe.modules = {
      vfio-pci = let
        vfio-pci-ids = mapAttrsToList (_: dev:
          "${dev.vendor}:${dev.product}"
          + optionalString (dev.subvendor != null) (
            ":${dev.subvendor}"
            + optionalString (dev.subproduct != null) ":${dev.subproduct}"
          )
        ) (filterAttrs (_: dev: (dev.enable && !dev.reserve)) cfg.devices);
      in mkIf (vfio-pci-ids != [ ]) {
        options.ids = concatStringsSep "," vfio-pci-ids;
      };
    };
  };
}
