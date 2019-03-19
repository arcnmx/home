{ config, pkgs, lib, ... } @ args: with lib; {
  options = {
    home.profiles.personal = lib.mkEnableOption "used as a day-to-day personal system";
    programs.ncmpcpp.mpdHost = mkOption {
      type = types.nullOr types.str;
      default = null;
    };
  };

  config = mkIf config.home.profiles.personal {
    home.rust.enable = true;
    home.file = let
      blocks_attr = "${pkgs.fetchgit {
        name = "task-blocks_attr.py";
        url = https://gist.github.com/wbsch/a2f7264c6302918dfb30.git;
        rev = "ff5d8f694371a274130ab4a639ce280c31e88a00";
        sha256 = "0prv5p0p1b0xhx89hjdxphyl4s2ln716mryhpmm8s3mf1d2wpifb";
        postFetch = ''
          chmod +x $out/on-modify.blocks_attr.py
        '';
      }}/on-modify.blocks_attr.py";
    in {
      ".task/hooks/on-add.blocks_attr.py".source = blocks_attr;
      ".task/hooks/on-launch.blocks_attr.py".source = blocks_attr;
      ".task/hooks/on-modify.blocks_attr.py".source = blocks_attr;
      ".taskrc".target = ".config/taskrc";
    };
    home.packages = with pkgs; with pkgs.arc; [
      pass-otp
      awscli
      ncmpcpp
      ncpamixer
      ledger
      taskwarrior
      physlock
      travis
      radare2
      jq yq
      #TODO: benc bsync snar-snapper book
    ];
    home.shell.aliases = {
      task3s = "task rc.context=3s";
      taskwork = "task rc.context=work";
      taskfun = "task rc.context=fun";
      taskrm = "task rc.confirmation=no delete";
    };

    home.sessionVariables = {
      TASKRC = "${config.xdg.configHome}/taskrc";
    };
    programs.taskwarrior = {
      enable = true;
      colorTheme = "solarized-light-256"; # TODO: shell alias to override and switch light/dark theme
      dataLocation = "${config.xdg.dataHome}/task";
      activeContext = "home";
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
