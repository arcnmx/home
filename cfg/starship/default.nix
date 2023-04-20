{ config, base16, lib, ... }: with lib; {
  programs.starship = with base16.map.ansiStr; let
    bg = "bg:${background_status}";
    substitutions = let
      expand = replaceStrings [ "$HOME" ] [ "~" ];
      mapDir = name: dir: nameValuePair (expand dir) "~${name}";
    in mapAttrs' mapDir config.programs.zsh.dirHashes;
    substitutionsList = mapAttrsToList (name: value: { inherit name value; }) substitutions;
    orderedSubstitutions = sort (a: b: a.name > b.name) substitutionsList;
  in {
    enable = mkDefault (!config.home.minimalSystem);
    extraConfig = mkMerge (
      singleton "[directory.substitutions]"
      ++ map ({ name, value }: ''"${name}" = "${value}"'') orderedSubstitutions
    );
    settings = {
      command_timeout = 200;
      add_newline = false;
      format =
        "[\${env_var.STARSHIP_TAG}$username$hostname$directory$all$shlvl$jobs$status$cmd_duration$fill$line_break](${bg} fg:${foreground_status})"
        + "$shell$character";
      right_format = "$package$battery$time";
      character = {
        format = "$symbol; ";
        success_symbol = ":";
        error_symbol = "[!](bold fg:${deleted})";
        vicmd_symbol = " ";
      };
      time = {
        format = "[🕓$time]($style)";
        style = "bold fg:${deprecated}";
        disabled = false;
      };
      fill = {
        symbol = " ";
        style = bg;
      };
      cmd_duration = {
        format = "[~$duration]($style)";
        style = "${bg} fg:${comment}";
        show_notifications = mkIf false (config.services.dunst.enable || config.services.kdeconnect.enable);
      };
      directory = {
        truncation_length = 0;
        truncate_to_repo = false;
        truncation_symbol = "…/";
        style = "${bg} bold fg:${function}";
      };
      env_var = {
        STARSHIP_TAG = {
          format = "[\\[$env_value\\]]($style) ";
          style = "${bg} bold fg:${foreground_status}";
        };
      };
      git_branch = {
        format = "[$symbol$branch]($style) ";
        style = "${bg} fg:${class}";
        symbol = "";
        #only_attached = true;
      };
      git_commit = {
        tag_disabled = false;
        inherit (config.programs.starship.settings.git_branch) style;
      };
      git_state = {
        # in-progress rebase/etc indicator
        format = "[:: $state( $progress_current/$progress_total)]($style) ";
        style = "${bg} bold fg:${deleted}";
      };
      git_status = {
        style = "${bg} fg:${deprecated}";
        # omit information that causes the prompt to lag severely: https://github.com/starship/starship/pull/3287
        ahead = "";
        behind = "";
        up_to_date = "";
        diverged = "";
        ignore_submodules = true;
        untracked = ""; # I kind of would like to keep this though..?
      };
      username = {
        format = "[$user]($style)@";
        style_user = "${bg} fg:${constant}";
        style_root = "${bg} bold fg:${keyword}";
      };
      hostname = {
        format = "[$hostname]($style):";
        style = "${bg} fg:${class}";
      };
      jobs = {
        style = "${bg} fg:${comment}";
      };
      nix_shell = {
        format = '' [$symbol($name)]($style) '';
        style = "${bg} fg:${support}";
        symbol = "#";
      };
      shlvl = {
        disabled = false;
        style = "${bg} bold fg:${deprecated}";
        symbol = "›";
        repeat = true;
        threshold = 3;
      };
      status = {
        disabled = false;
        format = "[$symbol$status]($style) ";
        symbol = "";
        success_symbol = "";
        sigint_symbol = "^";
        map_symbol = true;
        pipestatus = true;
        style = "${bg} bold fg:${deleted}";
      };
      package = {
        format = "[$symbol$version]($style) ";
        style = "bold fg:${class}";
      };
    } // mapListToAttrs (k: nameValuePair k { disabled = mkOptionDefault true; }) [
      # disable most builtin modules I'd never use...
      "battery" "vcsh"
      "aws" "azure" "gcloud" "kubernetes"
      "vagrant" "docker_context" "openstack" "singularity"
      "terraform" "pulumi" "helm"
      # useless modules that just show version numbers...
      "buf" "bun" "cmake" "cobol" "conda" "crystal" "dart" "deno" "dotnet" "elixir"
      "elm" "erlang" "fennel" "golang" "gradle" "haskell" "haxe" "java" "julia"
      "kotlin" "lua" "nim" "nodejs" "ocaml" "os" "perl" "php" "purescript"
      "python" "raku" "rlang" "red" "ruby" "rust" "scala" "swift" "vlang" "zig"
      # sorry mercurial
      "hg_branch"
      "fossil_branch"
    ];
  };
}
