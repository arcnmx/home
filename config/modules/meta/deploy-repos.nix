{ config, lib, pkgs, ... }: with lib; let
  target = config.deploy.targets.${cfg.target};
  tconfig = target.tf;
  tlib = tconfig.lib.tf;
  cfg = config.deploy.repos;
  inherit (tconfig.lib.tf) tfTypes;
  annexString = value:
    if value == true then "true"
    else if value == false then "false"
    else toString value;
  gitConfigCommands = config:
    mapAttrsToList (k: v: [ "git" "config" k v ]) config;
  gcryptType = types.submodule ({ config, name, ... }: {
    options = {
      enable = mkEnableOption "git-remote-gcrypt";
      participants = mkOption {
        type = types.listOf types.str;
      };
    };
  });
  annexEncryptionType = types.submodule ({ config, name, ... }: {
    options = {
      enable = mkEnableOption "git-annex encryption";
      mac = mkOption {
        type = types.enum [ "HMACSHA1" "HMACSHA256" "HMACSHA384" "HMACSHA512" ];
        default = "HMACSHA384";
      };
      type = mkOption {
        type = types.enum [ "hybrid" "shared" "pubkey" "sharedpubkey" ];
        default = "hybrid";
      };
      participants = mkOption {
        type = types.listOf types.str;
        default = [ ];
      };
      embed = mkOption {
        type = types.bool;
        default = true;
      };
      out = {
        extraConfig = mkOption {
          type = types.attrs;
          default = { };
        };
        enableConfig = mkOption {
          type = types.attrs;
          default = { };
        };
        additionalKeys = mkOption {
          type = types.listOf types.unspecified;
          default = [ ];
        };
      };
    };
    config.out = {
      extraConfig = mkIf config.enable {
        mac = config.mac;
        encryption = config.type;
        keyid = mkIf (config.participants != []) (builtins.head config.participants);
        embedcreds = if config.embed then "yes" else "no";
      };
      enableConfig = { };
      additionalKeys = mkIf config.enable (builtins.tail config.participants);
    };
  });
  annexRemoteS3Type = types.submodule ({ config, name, ... }: {
    options = {
      bucket = mkOption {
        type = types.str;
      };
      prefix = mkOption {
        type = types.str;
        #default = "";
      };
      out = mkOption {
        type = types.attrsOf types.unspecified;
        default = { };
      };
    };
    config = {
      out = {
        extraConfig = {
          type = "S3";
          inherit (config) bucket;
          fileprefix = config.prefix;
        };
        enableConfig = { };
      };
    };
  });
  annexRemoteRsyncType = types.submodule ({ config, name, ... }: {
    options = {
      url = mkOption {
        type = types.str;
      };
      out = mkOption {
        type = types.attrsOf types.unspecified;
        default = { };
      };
    };
    config = {
      out = {
        extraConfig = {
          type = "rsync";
          rsyncurl = config.url;
        };
        enableConfig = {
          rsyncurl = config.url;
        };
      };
    };
  });
  annexRemoteB2Type = types.submodule ({ config, name, ... }: {
    options = {
      bucket = mkOption {
        type = types.str;
      };
      prefix = mkOption {
        type = types.str;
        #default = "";
      };
      out = mkOption {
        type = types.attrsOf types.unspecified;
        default = { };
      };
    };
    config = {
      out = {
        extraConfig = {
          type = "external";
          externaltype = "b2";
          inherit (config) bucket prefix;
        };
        enableConfig = { };
      };
    };
  });
  annexRemoteDirectoryType = types.submodule ({ config, name, ... }: {
    options = {
      path = mkOption {
        type = types.nullOr types.str;
        default = null;
      };
      out = {
        extraConfig = mkOption {
          type = types.attrsOf types.unspecified;
          default = { };
        };
        enableConfig = mkOption {
          type = types.attrsOf types.unspecified;
          default = { };
        };
      };
    };
    config = {
      out = {
        extraConfig = {
          type = "directory";
          directory = config.path;
        };
        enableConfig = {
          inherit (config.out.extraConfig) directory;
        };
      };
    };
  });
  annexRemoteGitType = types.submodule ({ config, name, ... }: {
    options = {
      out = mkOption {
        type = types.attrsOf types.unspecified;
        default = { };
      };
      # location=...? apparently it must be the same as existing git
    };
    config = {
      out = {
        extraConfig = {
          type = "git";
          # inherit config.location;
        };
        enableConfig = { };
      };
    };
  });
  annexRemoteType = { defaults }: types.submoduleWith {
    modules = singleton ({ config, name, defaults, ... }: {
      options = {
        enable = mkOption {
          type = types.bool;
        };
        uuid = mkOption {
          type = types.nullOr types.str;
          default = null;
        };
        chunkSize = mkOption {
          type = types.nullOr types.str;
          default = null;
          # example "5MiB"
        };
        extraConfig = mkOption {
          type = types.attrsOf types.unspecified;
          default = { };
        };
        enableConfig = mkOption {
          type = types.attrsOf types.unspecified;
          default = { };
        };
        chunkType = mkOption {
          type = types.enum [ "chunk" "chunksize" ];
          default = "chunk";
          # chunksize is a legacy option
        };
        encryption = mkOption {
          type = annexEncryptionType;
          default = { };
        };
        s3 = mkOption {
          type = types.nullOr annexRemoteS3Type;
          default = null;
        };
        b2 = mkOption {
          type = types.nullOr annexRemoteB2Type;
          default = null;
        };
        directory = mkOption {
          type = types.nullOr annexRemoteDirectoryType;
          default = null;
        };
        rsync = mkOption {
          type = types.nullOr annexRemoteRsyncType;
          default = null;
        };
        git = mkOption {
          type = types.nullOr annexRemoteGitType;
          default = null;
        };
        out = {
          specialRemote = mkOption {
            type = types.unspecified;
            default = { };
          };
          initremote = mkOption {
            type = types.listOf (types.listOf types.str);
            default = { };
          };
          enableremote = mkOption {
            type = types.listOf types.str;
            default = { };
          };
        };
      };
      config = {
        enable = mkOptionDefault (config.uuid != null || config.extraConfig != {});
        encryption.participants = mkOptionDefault defaults.annex.participants;
        extraConfig = mkMerge [
          (mapAttrs (_: mkDefault) config.out.specialRemote.extraConfig)
          (mkIf (config.chunkSize != null) {
            ${config.chunkType} = mkDefault "${config.chunkSize}";
          })
          config.encryption.out.extraConfig
        ];
        enableConfig = mapAttrs (_: mkDefault) config.out.specialRemote.enableConfig
          // config.encryption.out.enableConfig;
        out = {
          specialRemote =
            if config.s3 != null then config.s3.out
            else if config.b2 != null then config.b2.out
            else if config.directory != null then config.directory.out
            else if config.rsync != null then config.rsync.out
            else if config.git != null then config.git.out
            else {
              extraConfig = { };
              enableConfig = { };
            };
          initremote = singleton (
            mapAttrsToList (k: v: "${k}=${annexString v}") config.extraConfig
          ) ++ map (key: config.out.enableremote ++ singleton "keyid+=${key}") config.encryption.out.additionalKeys;
          enableremote = mapAttrsToList (k: v: "${k}=${annexString v}") config.enableConfig;
        };
      };
    });
    specialArgs = {
      inherit defaults;
    };
  };
  awsRemoteType = { defaults }: types.submoduleWith {
    modules = singleton ({ config, name, defaults, ... }: {
      options = {
        create = mkOption {
          type = types.bool;
          default = true;
        };
        repo = mkOption {
          type = types.str;
          default = defaults.name;
        };
        description = mkOption {
          type = types.nullOr types.str;
          default = null;
        };
        region = mkOption {
          type = types.str;
          default = config.provider.out.provider.inputs.region;
        };
        provider = mkOption {
          type = tfTypes.providerReferenceType;
          default = cfg.defaults.providers.aws.set or "aws";
        };
        private = mkOption {
          type = types.bool;
          default = false;
        };
        out = {
          url = mkOption {
            type = types.unspecified;
          };
          httpsCloneUrl = mkOption {
            type = types.unspecified;
          };
          sshCloneUrl = mkOption {
            type = types.unspecified;
          };
          grcCloneUrl = mkOption {
            type = types.unspecified;
            description = "git-remote-codecommit";
          };
          arn = mkOption {
            type = types.unspecified;
          };
          repoResourceName = mkOption {
            type = types.str;
            default = tlib.terraformIdent "${config.repo}-aws";
          };
          repoResource = mkOption {
            type = types.unspecified;
            default = tconfig.resources.${config.out.repoResourceName};
          };
          cloneUrl = mkOption {
            type = types.unspecified;
            default = { };
          };
          setRepoResources = mkOption {
            type = types.attrsOf types.unspecified;
            default = { };
          };
        };
      };
      config = mkMerge [ (cfg.defaults.remoteConfig.aws or { }) {
        out = {
          url = "https://${config.region}.console.aws.amazon.com/codesuite/codecommit/repositories/${config.repo}/browse";
          httpsCloneUrl = "https://git-codecommit.${config.region}.amazonaws.com/v1/repos/${config.repo}";
          sshCloneUrl = "ssh://git-codecommit.${config.region}.amazonaws.com/v1/repos/${config.repo}";
          grcCloneUrl = "codecommit::${config.region}://${config.repo}";
          arn = "arn:aws:codecommit:${config.repo}:${config.accountNumber}:${config.repo}";
          cloneUrl = {
            # TODO: configure default protocol: ssh, https, grc
            fetch = config.out.sshCloneUrl;
            push = config.out.sshCloneUrl;
          };
          setRepoResources = mkIf config.create {
            ${config.out.repoResourceName} = {
              provider = config.provider.reference;
              type = mkDefault "codecommit_repository";
              inputs = mkMerge [ {
                repository_name = mkDefault config.repo;
                description = mkIf (config.description != null) (mkDefault config.description);
              } (cfg.defaults.providerConfig.aws or { }) ];
            };
          };
        };
      } ];
    });
    specialArgs = {
      inherit defaults;
    };
  };
  githubRemoteType = { defaults }: types.submoduleWith {
    modules = singleton ({ config, name, defaults, ... }: {
      options = {
        create = mkOption {
          type = types.bool;
          default = true;
        };
        owner = mkOption {
          type = types.str;
        };
        provider = mkOption {
          type = tfTypes.providerReferenceType;
          default = cfg.defaults.providers.github.set or "github";
        };
        repo = mkOption {
          type = types.str;
          default = defaults.name;
        };
        private = mkOption {
          type = types.bool;
          default = false;
        };
        out = {
          url = mkOption {
            type = types.unspecified;
          };
          httpsCloneUrl = mkOption {
            type = types.unspecified;
          };
          sshCloneUrl = mkOption {
            type = types.unspecified;
          };
          cloneUrl = mkOption {
            type = types.unspecified;
            default = { };
          };
          repoResourceName = mkOption {
            type = types.str;
            default = tlib.terraformIdent "${config.repo}-github";
          };
          repoResource = mkOption {
            type = types.unspecified;
            default = tconfig.resources.${config.out.repoResourceName};
          };
          setRepoResources = mkOption {
            type = types.attrsOf types.unspecified;
            default = { };
          };
        };
      };
      config = mkMerge [ (cfg.defaults.remoteConfig.github or { }) {
        owner = mkIf (config.provider.out.provider ? inputs.owner) (mkOptionDefault config.provider.out.provider.inputs.owner);
        out = {
          url = "https://github.com/${config.owner}/${config.repo}";
          httpsCloneUrl = "https://github.com/${config.owner}/${config.repo}.git";
          sshCloneUrl = "ssh://git@github.com/${config.owner}/${config.repo}.git";
          cloneUrl = {
            fetch = if config.private then config.out.sshCloneUrl else config.out.httpsCloneUrl;
            push = config.out.sshCloneUrl;
          };
          setRepoResources = mkIf config.create {
            ${config.out.repoResourceName} = {
              provider = config.provider.reference;
              type = mkDefault "repository";
              inputs = mkMerge [ {
                name = mkDefault config.repo;
                #description = mkIf (config.description != null) (mkDefault config.description);
                visibility = "private";
                # TODO: many other attrs could go here...
              } (cfg.defaults.providerConfig.github or { }) ];
            };
          };
        };
      } ];
    });
    specialArgs = {
      inherit defaults;
    };
  };
  repoRemoteType = { repo, defaults }: types.submoduleWith {
    modules = singleton ({ repo, config, name, defaults, ... }: {
      options = {
        name = mkOption {
          type = types.str;
          default = name;
        };
        gcrypt = mkOption {
          type = gcryptType;
          default = { };
        };
        github = mkOption {
          type = types.nullOr (githubRemoteType {
            inherit defaults;
          });
          default = null;
        };
        aws = mkOption {
          type = types.nullOr (awsRemoteType {
            inherit defaults;
          });
          default = null;
        };
        annex = mkOption {
          type = annexRemoteType {
            inherit defaults;
          };
          default = { };
        };
        cloneUrl = {
          fetch = mkOption {
            type = types.nullOr types.str;
          };
          push = mkOption {
            type = types.nullOr types.str;
            default = config.cloneUrl.fetch;
          };
        };
        extraConfig = mkOption {
          type = types.attrsOf types.unspecified;
          default = { };
        };
        out = {
          repoResources = mkOption {
            type = types.unspecified;
            default = mapAttrs (k: _: tconfig.resources.${k}) config.out.setRepoResources;
          };
          setRepoResources = mkOption {
            type = types.attrsOf types.unspecified;
            default = { };
          };
          cloneUrl = mkOption {
            type = types.unspecified;
            default = { };
          };
          add = mkOption {
            type = types.unspecified;
            default = { };
          };
          set = mkOption {
            type = types.unspecified;
            default = { };
          };
          init = mkOption {
            type = types.listOf (types.listOf types.str);
            default = { };
          };
        };
      };
      config = {
        gcrypt.participants = mkOptionDefault defaults.gcrypt.participants;
        cloneUrl = mkMerge [
          (mkIf (config.github != null) (mapAttrs (_: mkOptionDefault) {
            inherit (config.github.out.cloneUrl) fetch push;
          }))
          (mkIf (config.aws != null) (mapAttrs (_: mkOptionDefault) {
            inherit (config.aws.out.cloneUrl) fetch push;
          }))
          (mkIf config.annex.enable {
            fetch = mkOptionDefault null;
            push = mkOptionDefault null;
          })
        ];
        extraConfig = mkIf (repo.annex.enable && !config.annex.enable) {
          annex-ignore = mkDefault "true";
        };
        out = let
          gitConfig = gitConfigCommands (mapAttrs' (k: nameValuePair "remote.${name}.${k}") config.extraConfig);
        in {
          setRepoResources = mkMerge [
            (mkIf (config.github != null && config.github.create) config.github.out.setRepoResources)
            (mkIf (config.aws != null && config.aws.create) config.aws.out.setRepoResources)
          ];
          cloneUrl = if config.gcrypt.enable then {
            fetch = "gcrypt::${config.cloneUrl.fetch}";
            push = "gcrypt::${config.cloneUrl.push}";
          } else {
            inherit (config.cloneUrl) fetch push;
          };
          add =
            (if config.annex.enable then [
              ([ "git" "annex" "enableremote" name ] ++ config.annex.out.enableremote)
            ] else [
              [ "git" "remote" "add" name config.out.cloneUrl.fetch ]
            ] ++ optionals (config.out.cloneUrl.push != config.out.cloneUrl.fetch) [
              [ "git" "remote" "set-url" "--push" name config.out.cloneUrl.push ]
            ]) ++ gitConfig;
          set =
            (if config.annex.enable then [
              ([ "git" "annex" "enableremote" name ] ++ config.annex.out.enableremote)
            ] else [
              [ "git" "remote" "set-url" name config.out.cloneUrl.fetch ]
            ] ++ optionals (config.out.cloneUrl.push != config.out.cloneUrl.fetch) [
              [ "git" "remote" "set-url" "--push" name config.out.cloneUrl.push ]
            ]) ++ gitConfig;
          init =
            (if config.annex.enable then ([
              ([ "git" "annex" "initremote" name ] ++ builtins.head config.annex.out.initremote)
            ] ++ map (ir: [ "git" "annex" "enableremote" name ] ++ ir) (builtins.tail config.annex.out.initremote))
            else [
              [ "git" "remote" "add" name config.out.cloneUrl.fetch ]
            ] ++ optionals (config.out.cloneUrl.push != config.out.cloneUrl.fetch) [
              [ "git" "remote" "set-url" "--push" name config.out.cloneUrl.push ]
            ]) ++ gitConfig;
        };
      };
    });
    specialArgs = {
      inherit defaults repo;
    };
  };
  repoType = types.submodule ({ config, name, ... }: {
    options = {
      name = mkOption {
        type = types.str;
        default = name;
      };
      description = mkOption {
        type = types.nullOr types.str;
        default = null;
      };
      annex = {
        enable = mkOption {
          type = types.bool;
        };
        participants = mkOption {
          type = types.listOf types.str;
        };
      };
      gcrypt = mkOption {
        type = gcryptType;
        default = { };
      };
      remotes = mkOption {
        type = types.attrsOf (repoRemoteType {
          repo = config;
          defaults = {
            inherit (config.out) name;
            inherit (config) annex gcrypt;
          };
        });
        default = { };
      };
      environment = {
        init = mkOption {
          type = types.attrsOf types.str;
          default = { };
        };
        fetch = mkOption {
          type = types.attrsOf types.str;
          default = { };
        };
      };
      extraConfig = mkOption {
        type = types.attrsOf types.unspecified;
        default = { };
      };
      out = {
        name = mkOption {
          type = types.str;
        };
        repoResources = mkOption {
          type = types.unspecified;
          default = mapAttrs (k: _: tconfig.resources.${k}) config.out.setRepoResources;
        };
        setRepoResources = mkOption {
          type = types.attrsOf types.unspecified;
          default = { };
        };
        origin = mkOption {
          type = types.unspecified;
        };
        clone = mkOption {
          type = types.listOf (types.listOf types.str);
        };
        init = mkOption {
          type = types.listOf (types.listOf types.str);
        };
        run = mkOption {
          type = types.attrsOf types.unspecified;
        };
      };
    };
    config = {
      annex.enable = mkOptionDefault (any (r: r.annex.enable) (attrValues config.remotes));
      gcrypt.participants = mkOptionDefault cfg.defaults.gcrypt.participants;
      annex.participants = mkOptionDefault cfg.defaults.annex.participants;
      out = {
        name = config.name
          + optionalString config.annex.enable ".anx"
          + optionalString config.gcrypt.enable ".cry";
        setRepoResources = mkMerge (mapAttrsToList (_: r: r.out.setRepoResources) config.remotes);
        origin = config.remotes.origin or (findFirst (remote: !remote.annex.enable) null (attrValues config.remotes));
        clone = [
          ([ "git" "clone" config.out.origin.cloneUrl.fetch "." ]
            ++ optionals (config.out.origin.name != "origin") [ "-o" config.out.origin.name ]
          )
        ] ++ gitConfigCommands config.extraConfig
        ++ optionals (config.annex.enable) [
          [ "git" "annex" "init" ]
        ] ++ config.out.origin.out.set
        ++ concatLists (mapAttrsToList (_: remote: remote.out.add)
          (filterAttrs (_: remote: remote.name != config.out.origin.name) config.remotes));
        init = [
          [ "git" "init" ]
          [ "git" "remote" "add" config.out.origin.name config.out.origin.cloneUrl.fetch ]
          [ "git" "config-email" ]
          [ "git" "remote" "rm" config.out.origin.name ]
        ] ++ gitConfigCommands config.extraConfig
        ++ optionals (config.annex.enable) [
          [ "git" "annex" "init" ]
        ] ++ concatLists (mapAttrsToList (_: remote: remote.out.init) config.remotes);
        run = let
          f = k: v: with pkgs; nixRunWrapper {
            package = writeShellScriptBin k (''
              set -eu
            '' + concatStringsSep "\n" (map escapeShellArgs v));
          };
        in mapAttrs f {
          inherit (config.out) clone init;
        };
      };
    };
  });
in {
  options.deploy = {
    repos = {
      target = mkOption {
        type = types.str;
        default = "archive";
      };
      defaults = {
        providers = mkOption {
          type = types.attrsOf tfTypes.providerReferenceType;
          default = { };
        };
        providerConfig = mkOption {
          type = types.attrsOf (types.attrsOf types.unspecified);
          default = { };
        };
        remoteConfig = mkOption {
          type = types.attrsOf (types.attrsOf types.unspecified);
          default = { };
        };
        gcrypt = {
          participants = mkOption {
            type = types.listOf types.str;
            default = [ ];
          };
        };
        annex = {
          participants = mkOption {
            type = types.listOf types.str;
            default = [ ];
          };
        };
      };
      repos = mkOption {
        type = types.attrsOf repoType;
        default = { };
      };
      setResources = mkOption {
        type = types.attrsOf types.unspecified;
        default = { };
        internal = true;
      };
    };
  };
  config.deploy = {
    targets.${cfg.target} = {
      tf = {
        resources = cfg.setResources;
        runners.run = let
          f = repo: k: v: nameValuePair "${repo.name}-${k}" {
            command = ''
              set -eu

            '' + concatStrings (mapAttrsToList (k: v: "export ${k}=${v}\n") (repo.environment.init // repo.environment.fetch))
            + concatMapStringsSep "\n" escapeShellArgs v;
          };
          f' = repo: mapAttrs' (f repo) {
            inherit (repo.out) clone init;
          };
        in mkMerge (map f' (attrValues cfg.repos));
      };
    };
    repos = {
      setResources = mkMerge (mapAttrsToList (_: repo: repo.out.setRepoResources) cfg.repos);
    };
  };
}
