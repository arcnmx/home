{ config, pkgs, lib, ... } @ args: with lib; {
  options = {
    home.profiles.personal = lib.mkEnableOption "used as a day-to-day personal system";
    programs.ncmpcpp.mpdHost = mkOption {
      type = types.nullOr types.str;
      default = null;
    };
  };

  config = mkIf config.home.profiles.personal {
    home.file = {
      ".task/hooks/on-exit.task-blocks".source = pkgs.arc.task-blocks.on-exit;
      ".taskrc".target = ".config/taskrc";
      ".gnupg/gpg-agent.conf".target = ".config/gnupg/gpg-agent.conf";
    };
    home.packages = with pkgs; [
      pass-otp
      awscli
      ncmpcpp
      ncpamixer
      ledger
      physlock
      travis
      radare2
      jq yq
      #TODO: benc bsync snar-snapper book
    ];
    home.shell = {
      functions = {
        lorri-init = ''
          echo 'use ${if config.services.lorri.useNix then "nix" else "lorri"}' > .envrc && direnv allow
        '';
        task = ''
          local TASK_THEME=$(theme isDark && echo solarized-dark-256 || echo solarized-light-256)
          local TASK_DIR=$XDG_RUNTIME_DIR/taskwarrior
          mkdir -p "$TASK_DIR" &&
            ln -sf "${pkgs.taskwarrior}/share/doc/task/rc/$TASK_THEME.theme" "$TASK_DIR/theme" &&
            (cd "$TASK_DIR" && ${pkgs.taskwarrior}/bin/task "$@")
        '';
        tasks = ''
          #local _TASK_REPORT=next
          local _TASK_REPORT=
          if [[ $# -gt 0 ]]; then
              _TASK_REPORT=$1
              shift
          fi
          local _TASK_OPTIONS=(rc.defaultheight=$LINES rc.defaultwidth=$COLUMNS rc._forcecolor=yes limit:0)
          {
              if [[ -z $_TASK_REPORT ]]; then
                  #task "''${_TASK_OPTIONS[@]}" next "$@"
                  task "''${_TASK_OPTIONS[@]}" short "$@"
                  task "''${_TASK_OPTIONS[@]}" upcoming "$@"
              else
                  task "''${_TASK_OPTIONS[@]}" "$_TASK_REPORT" "$@"
              fi
          } 2> /dev/null | less
        '';
      };
      aliases = {
        task3s = "task rc.context=3s";
        taskwork = "task rc.context=work";
        taskfun = "task rc.context=fun";
        taskrm = "task rc.confirmation=no delete";
      };
    };

    home.sessionVariables = {
      TASKRC = "${config.xdg.configHome}/taskrc";
    };
    services.lorri.enable = true;
    services.gpg-agent = {
      enable = true;
      enableExtraSocket = true;
      enableScDaemon = false;
      enableSshSupport = true;
      extraConfig = ''
        pinentry-timeout 30
        allow-loopback-pinentry
        no-allow-external-cache
      '';
    };
    programs.taskwarrior = {
      enable = true;
      colorTheme = "solarized-light-256"; # TODO: shell alias to override and switch light/dark theme
      dataLocation = "${config.xdg.dataHome}/task";
      activeContext = "home";
      extraConfig = ''
        include ./theme
      '';
      contexts = {
        home = "(project.not:work and project.not:games and project.not:fun) or +escalate";
        fun = "project:fun";
        work = "project:work";
        "3s" = "project:games.3scapes";
      };
      aliases = {
        "3s" = "project:games.3scapes";
        ms2 = "project:games.maplestory2";
        annoate = "annotate";
        undelete = "modify status:pending end:"; # name this restore instead?
      };
      userDefinedAttributes = {
        priority = { # 0-9 priority, where default/empty is around 2.5
          label = "Priority";
          type = "string";
          values = [
            { value = "9"; color.foreground = "color255"; urgencyCoefficient = "8.0"; }
            { value = "8"; color.foreground = "color255"; urgencyCoefficient = "7.0"; }
            { value = "7"; color.foreground = "color255"; urgencyCoefficient = "6.0"; }
            { value = "6"; color.foreground = "color245"; urgencyCoefficient = "5.0"; }
            { value = "5"; color.foreground = "color245"; urgencyCoefficient = "4.0"; }
            { value = "4"; color.foreground = "color245"; urgencyCoefficient = "3.0"; }
            { value = "3"; color.foreground = "color245"; urgencyCoefficient = "2.0"; }
            { value = ""; }
            { value = "2"; color.foreground = "color250"; urgencyCoefficient = "-1.0"; }
            { value = "1"; color.foreground = "color250"; urgencyCoefficient = "-2.0"; }
            { value = "0"; color.foreground = "color250"; urgencyCoefficient = "-3.0"; }
          ];
        };
        blocks = { # blocks: hook
          type = "string";
          label = "Blocks";
        };
        blocked = { # blocked: hook
          type = "string";
          label = "Blocked";
        };
      };
      reports = {
        short = {
          description = "Abbreviated next report";
          filter = "status:pending limit:page +READY";
          columns = [
            { label = "ID"; id = "id"; }
            { label = "Active"; id = "start"; format = "age"; }
            { label = "Due"; id = "due"; format = "relative"; }
            { label = "Until"; id = "until"; format = "remaining"; }
            { label = "Description"; id = "description"; format = "count"; }
            { label = "Project"; id = "project"; }
            { label = "Tags"; id = "tags"; }
            { label = "Deps"; id = "depends"; }
            { label = "Urg"; id = "urgency"; sort = {
              priority = 0;
              order = "descending";
            }; }
          ];
        };
        upcoming = {
          description = "Abbreviated waiting report";
          filter = "+WAITING or (status:pending and -READY)";
          columns = [
            { label = "ID"; id = "id"; }
            { label = "A"; id = "start"; format = "active"; }
            { label = "Age"; id = "entry"; format = "age"; sort = {
              priority = 2;
              order = "ascending";
            }; }
            { label = "P"; id = "priority"; }
            { label = "Project"; id = "project"; }
            { label = "Tags"; id = "tags"; }
            { label = "Wait"; id = "wait"; sort = {
              priority = 1;
              order = "ascending";
            }; }
            { label = "Left"; id = "wait"; format = "remaining"; }
            { label = "S"; id = "scheduled"; format = "remaining"; }
            { label = "Due"; id = "due"; sort = {
              priority = 0;
              order = "ascending";
            }; }
            { label = "Until"; id = "until"; }
            { label = "Description"; id = "description"; format = "count"; }
          ];
        };
      };

      config = let cfg = config.programs.taskwarrior; in {
        default.command = "short";
        list.all = {
          projects = "yes";
          tags = "yes";
        };
        complete.all = {
          projects = "yes";
          tags = "yes";
        };
        recurrence.confirmation = "no";
        bulk = 7;
        nag = "";

        verbose = ["blank" "header" "footnote" "label" "new-id" "new-uuid" "affected" "edit" "special" "project" "unwait" "recur"]; # removed: override, sync

        urgency = {
          blocking.coefficient = "1.0";
          annotations.coefficient = "0.0";
          scheduled.coefficient = "0.5";

          user.tag = {
            routine.coefficient = "9.0";
            review.coefficient = "2.0";
            escalate.coefficient = "0.5";
            READY.coefficient = "30.0";
          };
        };
      };
    };

    xdg.configFile = {
      "ncmpcpp/bindings".source = ./files/ncmpcpp-bindings;
      "ncmpcpp/config".source = pkgs.substituteAll {
        inherit (config.programs.ncmpcpp) mpdHost;
        src = ./files/ncmpcpp-config;
      };
    };
  };
}
