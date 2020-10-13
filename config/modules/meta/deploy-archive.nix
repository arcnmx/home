{ pkgs, config, lib, ... }: with lib; let
  cfg = config.deploy.archive;
  target = config.deploy.targets.archive-backup;
  borg = "${cfg.borg.package}/bin/borg";
  exportPassphrase = optionalString (cfg.borg.passphraseShellCommand != null)
    ''export BORG_PASSPHRASE="''${BORG_PASSPHRASE-$(${cfg.borg.passphraseShellCommand})}"'';
  archiveNameFor = state: path:
    if state.name == path.name then state.name
    else "${key}-${path.name}";
  archiveNameForDatabase = type: state: db:
    (if state.name == db then state.name
    else "${state.name}-${db}") + "-${type}";
  latestArchiveFor = state: path:
    mapNullable (key: "${archiveNameFor state path}-${key}") cfg.borg.latestArchive.${state.name};
  latestArchiveForDatabase = type: state: db:
    mapNullable (key: "${archiveNameForDatabase type state db}-${key}") cfg.borg.latestArchive.${state.name};
  sshFor = target: with target.tf.runners.run."${target.name}-ssh";
    "${package}/bin/${executable}";
  sshfsFor = target: dir: mountpoint: let
    ssh = target.tf.outputs."${target.tf.deploy.systems.${target.name}.out.resourceName}_ssh".import;
    opts = concatStringsSep " " (mapAttrsToList (k: v: "-o ${escapeShellArg "${k} ${v}"}") ssh.opts);
    portOpt = optionalString (ssh.port != null) "-p ${toString ssh.port}";
    sshCommand = "${pkgs.openssh}/bin/ssh ${portOpt} ${opts}";
    sshExec = pkgs.writeShellScript "sshfs-ssh" ''
      set -eu

      exec ${sshCommand} "$@"
    '';
  in ''${pkgs.sshfs}/bin/sshfs "${ssh.host}:${toString dir}" "${mountpoint}" -o ssh_command=${sshExec} -o idmap=user'';
  scriptHeader = {
    system
  , target
  , state
  }: ''
    set -euo pipefail

    ${sshFor target} true # check connectivity

    ${exportPassphrase}
    BORG_ARGS=(
      --warning
      --files-cache=ctime,size -p -s -C lzma -e 'tmp.*'
    )

    MOUNT_DIR=$(mktemp -d)
    cleanup() {
      fusermount -u "$MOUNT_DIR" || true
      rmdir "$MOUNT_DIR" || true
    }
    trap cleanup EXIT
  '' + optionalString (state.serviceNames != []) ''
    ${sshFor target} systemctl stop ${escapeShellArgs state.serviceNames}
  '';
  scriptFooter = {
    system
  , target
  , state
  }: optionalString (state.serviceNames != []) ''
    ${sshFor target} systemctl start ${escapeShellArgs state.serviceNames} || true
  '';
  scriptRestorePath = {
    path
  , target
  , borgArchive
  }: ''
    BORG_EXCLUDES=(
      "''${BORG_ARGS[@]}"
      ${concatMapStringsSep " " (p: "-e ${escapeShellArg p}") (path.exclude ++ path.excludeExtract)}
    )
    ${borg} mount -o nonempty,uid=$(id -u) "''${BORG_EXCLUDES[@]}" "${toString cfg.borg.repoDir}::${borgArchive}" "$MOUNT_DIR"

    # wow rsync is bad with globs?
    ${pkgs.rsync}/bin/rsync --progress -e "${sshFor target}" -rav --usermap=\\\*:${path.owner} --groupmap=\\\*:${path.group} "$MOUNT_DIR/" ":${toString path.path}/"

    cleanup
  '';
  scriptBackupPath = {
    path
  , target
  , borgArchive
  }: ''
    BORG_EXCLUDES=(
      "''${BORG_ARGS[@]}"
      ${concatMapStringsSep " " (p: "-e ${escapeShellArg p}") path.exclude}
    )

    # TODO: use idmap files?
    ${sshfsFor target path.path "$MOUNT_DIR"}

    (cd "$MOUNT_DIR" && ${borg} create "''${BORG_EXCLUDES[@]}" "${toString cfg.borg.repoDir}::${borgArchive}" .)

    cleanup
  '';
  scriptRestoreDatabasePostgresql = {
    dbName
  , target
  , borgArchive
  , fileName ? "stdin" # "postgresql.sql" when --stdin-name is supported?
  }: ''
    ${borg} extract --stdout "${toString cfg.borg.repoDir}::${borgArchive}" ${fileName} | ${sshFor target} -CT sudo -u postgres psql --set ON_ERROR_STOP=on "${dbName}"
  '';
  scriptBackupDatabasePostgresql = {
    dbName
  , target
  , borgArchive
  , fileName ? null # "postgresql.sql" when --stdin-name is supported?
  }: ''
    ${sshFor target} -CT sudo -u postgres pg_dump "${dbName}" | ${borg} create "''${BORG_ARGS[@]}" ${optionalString (fileName != null) "--stdin-name ${escapeShellArg fileName}"} "${toString cfg.borg.repoDir}::${borgArchive}" -
  '';
  restoreScript = {
    system
  , target
  , state
  , borgArchiveFor
  }: ''
    ${scriptHeader { inherit system target state; }}
  '' + concatMapStringsSep "\n" (path: let
    borgArchive = borgArchiveFor { inherit state path; };
  in if borgArchive == null then "" else scriptRestorePath {
    inherit path target borgArchive;
  }) state.paths + concatMapStringsSep "\n" (dbName: let
    borgArchive = borgArchiveFor {
      inherit state;
      db = {
        name = dbName;
        type = "postgresql";
      };
    };
  in if borgArchive == null then "" else scriptRestoreDatabasePostgresql {
    inherit dbName target borgArchive;
  }) state.databases.postgresql + ''
    ${scriptFooter { inherit system target state; }}
  '';
  backupScript = {
    system
  , target
  , state
  , borgArchiveFor
  }: ''
    ${scriptHeader { inherit system target state; }}
  '' + concatMapStringsSep "\n" (path: let
  in scriptBackupPath {
    inherit path target;
    borgArchive = borgArchiveFor { inherit state path; };
  }) state.paths + concatMapStringsSep "\n" (dbName: let
  in scriptBackupDatabasePostgresql {
    inherit dbName target;
    borgArchive = borgArchiveFor {
      inherit state;
      db = {
        name = dbName;
        type = "postgresql";
      };
    };
  }) state.databases.postgresql + ''
    ${scriptFooter { inherit system target state; }}
  '';
  nixosModule = { config, target, ... }: {
    config.runners.run = mkMerge (mapAttrsToList (name: state: let
      system = config;
    in {
      "state-${name}-restore".command = let
        borgArchiveFor = { state, db ? null, path ? null }: let
          dbArchive = latestArchiveForDatabase db.type state db.name;
          archive = latestArchiveFor state path;
        in if db != null then dbArchive else archive;
        script = restoreScript { inherit system target state borgArchiveFor; };
      in ''
        set -eu

        exec ${pkgs.writeShellScript "state-${name}-restore" script} "$@"
      '';
      "state-${name}-backup".command = let
        borgArchiveFor = { state, db ? null, path ? null }: let
          postfix = "$POSTFIX";
          dbArchive = "${archiveNameForDatabase db.type state db.name}-${postfix}";
          archive = "${archiveNameFor state path}-${postfix}";
        in if db != null then dbArchive else archive;
        script = backupScript {
          inherit system target state borgArchiveFor;
        };
      in ''
        set -eu

        export POSTFIX=$1

        exec ${pkgs.writeShellScript "state-${name}-backup" script}
      '';
    }) config.deploy.mutableState);
  };
  activeStates' = concatMap (node: map (state: {
    inherit node state;
  }) (filter (s: s.enable) (attrValues node.deploy.mutableState))) (attrValues config.network.nodes);
  activeStates = activeStates' ++ map (name: {
    state = {
      inherit name;
      enable = false;
      instanced = false; # TODO?
    };
    node = null;
  }) cfg.borg.retiredArchives;
  backupResources = { node, state }: let
    resourceName = optionalString state.instanced "${node.networking.hostName}-" + state.name;
    tf = target.tf;
  in {
    "${resourceName}-expiry" = {
      provider = "time";
      type = "rotating";
      inputs = if state.enable then {
        rotation_days = state.backup.frequency.days;
      } else {
        rotation_years = 99;
      };
    };
    "${resourceName}-backup" = {
      provider = "null";
      type = "resource";
      inputs = {
        triggers = {
          expiry = tf.resources."${resourceName}-expiry".refAttr "id";
        };
      };
      provisioners = mkIf state.enable [ {
        local-exec = {
          command = "nix run -f ${toString ../../..} network.nodes.${node.networking.hostName}.run.state-${state.name}-backup -c run ${tf.lib.tf.terraformSelf "id"}";
        };
      } ];
    };
  };
in {
  options.deploy.archive = {
    borg = {
      repoDir = mkOption {
        type = types.path;
      };
      keyFile = mkOption {
        type = types.path;
      };
      passphraseShellCommand = mkOption {
        type = types.nullOr types.str;
        default = null;
      };
      retiredArchives = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "Add unused archive names here to prevent them from being deleted from terraform state";
      };
      latestArchive = mkOption {
        type = types.attrsOf (types.nullOr types.str);
        default = { };
      };
      package = mkOption {
        type = types.package;
        default = pkgs.writeShellScriptBin "borg" ''
          export BORG_REPO="${toString cfg.borg.repoDir}"
          export BORG_KEY_FILE="${toString cfg.borg.keyFile}"
          ${exportPassphrase}

          exec ${pkgs.borgbackup}/bin/borg "$@"
        '';
      };
    };
  };
  options.network.nodes = mkOption {
    type = types.attrsOf (types.submoduleWith {
      modules = singleton nixosModule;
    });
  };
  config = {
    deploy.targets.archive-backup = {
      tf = {
        terraform.environment.TF_CLI_ARGS_apply = "-parallelism=1";
        resources = mkMerge (map backupResources activeStates);
      };
    };
    deploy.archive.borg.latestArchive = mapListToAttrs ({ node, state }: let
      resourceName = optionalString state.instanced "${node.networking.hostName}-" + state.name;
      postfix = target.tf.resources."${resourceName}-backup".importAttr "id";
    in nameValuePair state.name postfix) activeStates;
  };
}
