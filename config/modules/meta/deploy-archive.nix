{ pkgs, config, lib, ... }: with lib; let
  cfg = config.deploy.archive;
  repo = cfg.borg.repos.${config.deploy.idTag};
  borg-repos = cfg.borg.repos.repos;
  target = config.deploy.targets.archive-backup;
  borg = "${repo.package}/bin/borg";
  borgArgs = [
    "--warning"
    "-e" "tmp.*"
  ];
  borgArgsBackup = borgArgs ++ [
    "--files-cache=mtime,size" "-p" "-s"
    "-C" "lzma"
  ];
  borgArgsRestore = borgArgs;
  exportPassphrase = passphraseShellCommand: optionalString (passphraseShellCommand != null)
    ''BORG_PASSPHRASE="''${BORG_PASSPHRASE-$(${passphraseShellCommand})}"'' + "\nexport BORG_PASSPHRASE";
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
  in ''${pkgs.sshfs}/bin/sshfs "${ssh.host}:${toString dir}" "${mountpoint}" -o ssh_command=${sshExec} -o idmap=user -o reconnect'';
  scriptHeader = {
    system
  , target
  , state
  }: ''
    set -euo pipefail

    ${sshFor target} true # check connectivity

    ${exportPassphrase repo.passphraseShellCommand}

    # a stable path is important for the borg file cache to work
    MOUNT_DIR="''${TMPDIR-/tmp}/archive-${state.name}.mount"

    if [[ -d $MOUNT_DIR ]]; then
      rmdir "$MOUNT_DIR"
    fi
    mkdir "$MOUNT_DIR"

    restore-readkey() {
      local STATE_KEY
      STATE_KEY=$1
      ${sshFor target} "cat '${system.deploy.stateDirectory}/$STATE_KEY' 2> /dev/null || true"
    }

    restore-writekey() {
      local STATE_KEY STATE_VALUE
      STATE_KEY=$1
      STATE_VALUE=$2
      ${sshFor target} "mkdir -p ${system.deploy.stateDirectory} && printf %s '$STATE_VALUE' > '${system.deploy.stateDirectory}/$STATE_KEY'"
    }

    unmount() {
      fusermount -u "$MOUNT_DIR"
    }
    cleanup() {
      unmount || true
      rmdir "$MOUNT_DIR" || true
    }
    trap cleanup EXIT
  '' + optionalString (state.serviceNames != []) ''
    if ${sshFor target} systemctl is-active ${escapeShellArgs state.serviceNames} > /dev/null; then
      ${sshFor target} systemctl stop ${escapeShellArgs state.serviceNames}
      STOP_SERVICES=1
    fi
  '';
  scriptFooter = {
    system
  , target
  , state
  }: optionalString (state.serviceNames != []) ''
    if [[ -n ''${STOP_SERVICES-} ]]; then
      ${sshFor target} systemctl start ${escapeShellArgs state.serviceNames} || true
    fi
  '';
  scriptRestorePath = {
    path
  , state
  , target
  , borgArchive
  }: let
    archiveKey = archiveNameFor state path;
  in ''
    RESTORE_KEY=$(restore-readkey "${archiveKey}")
    if [[ -n $RESTORE_KEY ]]; then
      echo "skipping restore of ${borgArchive}" >&2
    else
      BORG_EXCLUDES=(
        "''${BORG_ARGS[@]}"
        ${concatMapStringsSep " " (p: "-e ${escapeShellArg p}") (path.exclude ++ path.excludeExtract)}
      )
      ${borg} mount -o nonempty,uid=$(id -u) "''${BORG_EXCLUDES[@]}" "${toString repo.repoDir}::${borgArchive}" "$MOUNT_DIR"

      # wow rsync is bad with globs?
      ${pkgs.rsync}/bin/rsync --progress -e "${sshFor target}" -rav --usermap=\\\*:${path.owner} --groupmap=\\\*:${path.group} "$MOUNT_DIR/" ":${toString path.path}/"

      restore-writekey "${archiveKey}" "${borgArchive}"

      unmount
    fi
  '';
  scriptBackupPath = {
    path
  , state
  , target
  , borgArchive
  }: ''
    BORG_EXCLUDES=(
      "''${BORG_ARGS[@]}"
      ${concatMapStringsSep " " (p: "-e ${escapeShellArg p}") path.exclude}
    )

    # TODO: use idmap files?
    ${sshfsFor target path.path "$MOUNT_DIR"}

    (cd "$MOUNT_DIR" && ${borg} create "''${BORG_EXCLUDES[@]}" "${toString repo.repoDir}::${borgArchive}" .)

    restore-writekey "${archiveNameFor state path}" "${borgArchive}"

    unmount
  '';
  scriptRestoreDatabasePostgresql = {
    dbName
  , system
  , state
  , target
  , borgArchive
  #, fileName ? "stdin" # "postgresql.sql" when --stdin-name is supported?
  }: let
    archiveKey = archiveNameForDatabase "postgresql" state dbName;
    psql = "${sshFor target} -CT sudo -u postgres psql --set ON_ERROR_STOP=on";
    ensureUsers = filter (u: u.ensurePermissions ? "DATABASE ${dbName}") system.services.postgresql.ensureUsers;
  in ''
    RESTORE_KEY=$(restore-readkey "${archiveKey}")
    if [[ -n $RESTORE_KEY ]]; then
      echo "skipping restore of ${borgArchive}" >&2
    else
      # ensureDatabases ahead of switch
      ${psql} -tAc "\"SELECT 1 FROM pg_database WHERE datname = '${dbName}'\"" | grep -q 1 ||
        ${psql} -tAc "'CREATE DATABASE \"${dbName}\"'" # TODO: some services like matrix need special settings
      ${concatMapStringsSep "\n" (user: ''
        ${psql} -tAc "\"SELECT 1 FROM pg_roles WHERE rolname='${user.name}'\"" | grep -q 1 ||
          ${psql} -tAc "'CREATE USER \"${user.name}\"'"
        #${psql} -tAc "'GRANT ${user.ensurePermissions."DATABASE ${dbName}"} ON DATABASE \"${dbName}\" TO \"${user.name}\"'"
      '') ensureUsers}

      ${borg} extract --stdout "${toString repo.repoDir}::${borgArchive}" | ${psql} "${dbName}"

      restore-writekey "${archiveKey}" "${borgArchive}"
    fi
  '';
  scriptBackupDatabasePostgresql = {
    dbName
  , state
  , target
  , borgArchive
  , fileName ? "postgresql.sql"
  }: ''
    ${sshFor target} -CT sudo -u postgres pg_dump "${dbName}" | ${borg} create "''${BORG_ARGS[@]}" ${optionalString (fileName != null) "--stdin-name ${escapeShellArg fileName}"} "${toString repo.repoDir}::${borgArchive}" -

    restore-writekey "${archiveNameForDatabase "postgresql" state dbName}" "${borgArchive}"
  '';
  restoreScript = {
    system
  , target
  , state
  , borgArchiveFor
  }: ''
    BORG_ARGS=(${escapeShellArgs borgArgsRestore})
    ${scriptHeader { inherit system target state; }}
  '' + concatMapStringsSep "\n" (path: let
    borgArchive = borgArchiveFor { inherit state path; };
  in if borgArchive == null then "" else scriptRestorePath {
    inherit state path target borgArchive;
  }) state.paths + concatMapStringsSep "\n" (dbName: let
    borgArchive = borgArchiveFor {
      inherit state;
      db = {
        name = dbName;
        type = "postgresql";
      };
    };
  in if borgArchive == null then "" else scriptRestoreDatabasePostgresql {
    inherit system state dbName target borgArchive;
  }) state.databases.postgresql + ''
    ${scriptFooter { inherit system target state; }}
  '';
  backupScript = {
    system
  , target
  , state
  , borgArchiveFor
  }: ''
    BORG_ARGS=(${escapeShellArgs borgArgsBackup})
    ${scriptHeader { inherit system target state; }}
  '' + concatMapStringsSep "\n" (path: let
  in scriptBackupPath {
    inherit state path target;
    borgArchive = borgArchiveFor { inherit state path; };
  }) state.paths + concatMapStringsSep "\n" (dbName: let
  in scriptBackupDatabasePostgresql {
    inherit state dbName target;
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
  mutableStateModule = { config, ... }: {
    options = {
      backup = {
        frequency.days = mkOption {
          type = types.int;
          default = 3;
        };
      };
      restore = {
        enable = mkEnableOption "restore on enable" // { default = true; };
      };
    };
  };
  nixosModule = { name, config, target, tf, ... }: {
    options.deploy.stateDirectory = mkOption {
      type = types.path;
      default = "/var/lib/arc/archive";
    };
    options.system.mutableState.services = mkOption {
      type = types.attrsOf (types.submodule mutableStateModule);
    };
    config.runners.run = mkMerge (mapAttrsToList (name: state: let
      system = config;
    in {
      "state-${state.name}-restore".command = let
        borgArchiveFor = { state, db ? null, path ? null }: let
          dbArchive = latestArchiveForDatabase db.type state db.name;
          archive = latestArchiveFor state path;
        in if db != null then dbArchive else archive;
        script = restoreScript { inherit system target state borgArchiveFor; };
      in ''
        set -eu

        exec ${pkgs.writeShellScript "state-${name}-restore" script} "$@"
      '';
      "state-${state.name}-backup".command = let
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
    }) config.system.mutableState.services);
    config.deploy.tf = mkMerge (mapAttrsToList (k: state: mkIf (state.enable && state.restore.enable) {
      resources."restore-${state.name}" = {
        provider = "null";
        type = "resource";
        inputs.triggers = removeAttrs (tf.deploy.systems.${name}.triggers.common // tf.deploy.systems.${name}.triggers.copy) [ "system" ];
        provisioners = [
          {
            local-exec = {
              command = escapeShellArgs config.runners.lazy.run."state-${state.name}-restore".out.runArgs;
            };
          }
        ];
      };
      deploy.systems.${name}.triggers.switch = {
        "restore-${state.name}" = tf.resources."restore-${state.name}".refAttr "id";
      };
    }) config.system.mutableState.services);
    config.system.activationScripts.restore = let
      enabledState = filterAttrs (_: s: s.enable && s.restore.enable) config.system.mutableState.services;
      mapPath = path: ''
        ARCHIVE_RESTORE_PATHS=(${path.path}/*)
        if [[ $(stat --format '%U' "''${ARCHIVE_RESTORE_PATHS[0]}") != "${path.owner}" ]]; then
          chown -R "${path.owner}:${path.group}" "${path.path}"
        fi
      '';
      mapState = key: state: ''
        # ${key} restore archive
      '' + concatMapStringsSep "\n" mapPath state.paths;
    in mkIf (enabledState != { }) {
      text = mkMerge (mapAttrsToList mapState enabledState);
      deps = [ "users" ];
    };
  };
  activeStates' = concatMap (node: map (state: {
    inherit node state;
  }) (filter (s: s.enable) (attrValues node.system.mutableState.services))) (attrValues config.network.nodes);
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
          command = escapeShellArgs (node.runners.lazy.run."state-${state.name}-backup".out.runArgs ++ singleton (tf.lib.tf.terraformSelf "id"));
        };
      } ];
    };
  };
  backupRepoResources = { repo }: let
    resourceName = repo.name;
    tf = target.tf;
  in {
    "${resourceName}-expiry" = {
      provider = "time";
      type = "rotating";
      inputs = if repo.enable then {
        rotation_days = 2;
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
      provisioners = mkIf repo.enable [ {
        local-exec = {
          command = escapeShellArgs target.tf.runners.lazy.run."${repo.name}-backup".out.runArgs + " ${tf.lib.tf.terraformSelf "id"}";
        };
      } ];
    };
  };
  borgRepoSubmodule = { config, ... }: {
    options = {
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
      package = mkOption {
        type = types.package;
        default = pkgs.writeShellScriptBin "borg" ''
          export BORG_RELOCATED_REPO_ACCESS_IS_OK=yes
          export BORG_REPO="${toString config.repoDir}"
          export BORG_KEY_FILE="${toString config.keyFile}"
          ${exportPassphrase config.passphraseShellCommand}

          exec ${pkgs.borgbackup}/bin/borg "$@"
        '';
      };
    };
  };
  borgRepoType = types.submoduleWith {
    modules = singleton borgRepoSubmodule;
  };
  backupRepoScript = { cloneUrl, path, borgArchive }: let
    git = "${pkgs.gitMinimal}/bin/git";
  in ''
    set -eu

    if [[ ! -d ${path} ]]; then
      git clone --mirror "${cloneUrl}" ${path}
      cd ${path}
      ${git} config core.compression 0
      ${git} config core.looseCompression 0
      ${git} config pack.compression 0
      ${git} repack -Fad --depth=250 --window=250
    else
      cd ${path}
      git remote set-url origin "${cloneUrl}"
    fi
    ${git} remote update
    ${git} gc --prune=now

    BORG_ARGS=(${escapeShellArgs borgArgs})
    ${borg-repos.package}/bin/borg create "''${BORG_ARGS[@]}" "${toString borg-repos.repoDir}::${borgArchive}" .
  '';
  backupRepoType = types.submodule ({ config, name, ... }: {
    options = {
      enable = mkOption {
        type = types.bool;
        default = true;
      };
      name = mkOption {
        type = types.str;
        default = name;
      };
      cloneUrl = mkOption {
        type = types.str;
      };
    };
  });
in {
  options.deploy.archive = {
    borg = {
      repos = mkOption {
        type = types.attrsOf borgRepoType;
        default = { };
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
    };
    repos = {
      repos = mkOption {
        type = types.attrsOf backupRepoType;
        default = { };
      };
      workingDir = mkOption {
        type = types.path;
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
        resources = mkMerge (
          map backupResources activeStates
          ++ map backupRepoResources (mapAttrsToList (_: repo: { inherit repo; }) cfg.repos.repos)
        );
        runners.run = mkMerge [
          (mapAttrs' (k: repo: nameValuePair "borg-${k}" {
            package = repo.package;
            executable = "borg";
          }) cfg.borg.repos)
          (mapAttrs' (k: repo: nameValuePair "${repo.name}-backup" {
            command = let
              path = cfg.repos.workingDir + "/${repo.name}";
              script = backupRepoScript {
                path = "$BACKUP_PATH";
                cloneUrl = "$BACKUP_CLONE_URL";
                borgArchive = "$BACKUP_ARCHIVE";
              };
            in ''
              set -eu

              export BACKUP_ARCHIVE="${repo.name}-$1"
              export BACKUP_PATH="${toString path}"
              export BACKUP_CLONE_URL="${repo.cloneUrl}"

              exec ${pkgs.writeShellScript "repo-backup" script}
            '';
          }) cfg.repos.repos)
        ];
      };
    };
    deploy.archive = {
      borg.latestArchive = mapListToAttrs ({ node, state }: let
        resourceName = optionalString state.instanced "${node.networking.hostName}-" + state.name;
        postfix = target.tf.resources."${resourceName}-backup".importAttr "id";
      in nameValuePair state.name postfix) activeStates;
      repos.repos = mapAttrs (k: repo: {
        name = mkDefault repo.name;
        cloneUrl = mkDefault repo.out.origin.out.cloneUrl.fetch;
      }) config.deploy.repos.repos;
    };
  };
}
