{ base16, config, pkgs, lib, ... } @ args: with lib; let
  cfg = config.home.profileSettings.personal;
in {
  programs.taskwarrior = let
    theme = import ./taskwarrior-theme.nix {
      inherit pkgs lib base16;
    };
  in {
    enable = true;
    dataLocation = "${config.xdg.dataHome}/task";
    activeContext = "home";
    extraConfig = ''
      include ${theme}
    '';
    contexts = {
      home = "(project.not:work and project.not:games and project.not:fun and project.not:home.shopping.) or +escalate";
      fun = "project:fun";
      work = "project:work";
      shop = "project:home.shopping";
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
        filter = "status:pending limit:page +READY -longterm";
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
      longterm = {
        description = "Long-term tasks";
        filter = "status:pending limit:page +READY +longterm";
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

    config = {
      default.command = "short";
      list.all = {
        projects = "yes";
        tags = "yes";
      };
      complete.all = {
        projects = "yes";
        tags = "yes";
      };
      reserved.lines = "2";
      recurrence = if cfg.isPrimary then {
        confirmation = "no";
      } else "off"; # https://github.com/GothenburgBitFactory/taskserver/issues/46
      bulk = 7;
      nag = "";

      verbose = ["header" "footnote" "label" "new-id" "new-uuid" "affected" "edit" "special" "project" "unwait" "recur"]; # removed: blank, override, sync

      urgency = {
        blocking.coefficient = "1.0";
        annotations.coefficient = "0.0";
        scheduled.coefficient = "0.5";

        user.tag = {
          commit.coefficient = "10.0";
          remote.coefficient = "-0.9";
          routine.coefficient = "9.0";
          review.coefficient = "2.0";
          escalate.coefficient = "0.5";
          READY.coefficient = "30.0";
        };
      };
    };
  };
  home.shell = {
    aliases = {
      vit = "task vit";
      task3s = "task rc.context=3s";
      taskwork = "task rc.context=work";
      taskfun = "task rc.context=fun";
      taskrm = "task rc.confirmation=no delete";
    };
    functions = {
      task = ''
        local TASK_EXEC=${pkgs.taskwarrior}/bin/task
        if [[ ''${1-} = vit ]]; then
          shift
          TASK_EXEC=${pkgs.vit}/bin/vit
        fi
        local TASK_DIR=$XDG_RUNTIME_DIR/taskwarrior
        mkdir -p "$TASK_DIR" &&
          (cd "$TASK_DIR" && "$TASK_EXEC" "$@")
      ''; # NOTE: link theme to $TASK_DIR/theme and `include ./theme` - can be conditional on $(theme isDark)
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
                task "''${_TASK_OPTIONS[@]}" longterm "$@"
                task "''${_TASK_OPTIONS[@]}" upcoming "$@"
            else
                task "''${_TASK_OPTIONS[@]}" "$_TASK_REPORT" "$@"
            fi
        } 2> /dev/null | ''${PAGER-less -R}
      '';
    };
  };
  home.file = with pkgs.arc.packages.personal.task-blocks; {
    ".task/hooks/on-exit.task-blocks".source = on-exit;
    ".task/hooks/on-add.task-blocks".source = on-add;
    ".task/hooks/on-modify.task-blocks".source = on-modify;
  };
}
