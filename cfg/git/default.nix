{ config, pkgs, lib, ... }: with lib; {
  programs.git = {
    enable = !config.home.minimalSystem;
    package = mkDefault pkgs.gitMinimal;
    aliases = {
      logs = "log --stat --pretty=medium --show-linear-break";
      reattr = "!${pkgs.writeShellScript "git-reattr.sh" ''
        git stash push -q
        rm .git/index
        git checkout HEAD -- "$(git rev-parse --show-toplevel)"
        git stash pop || true
      ''}";
    };
    ignores = [
      ".envrc*"
      ".direnv/"
    ];
    extraConfig = {
      core = {
        pager = let
          pager = if config.programs.page.enable
            then "$PAGER -t git"
            else "$PAGER";
          # TODO: unsure how to get page/vim to handle tabs, so...
          filter = "sed 's/\t/  /g' |";
        in filter + pager;
      };
      user = {
        useConfigOnly = true;
      };
      color = {
        ui = if config.programs.bat.enable then "never" else "auto";
        status = "auto";
        diff = "auto";
      };
      push = {
        default = "simple";
      };
      init = {
        defaultBranch = "main";
      #  templateDir = "${pkgs.gitAndTools.hook-chain}";
      };
      annex = {
        backend = "SHA256"; # TODO: blake3 when?
        autocommit = false;
        synccontent = true;
        jobs = 8;
      };
      rebase = {
        autoSquash = true;
        autoStash = true;
      };
      merge = {
        conflictstyle = "diff3";
      };
      filter.tabspace = {
        smudge = "${pkgs.coreutils}/bin/unexpand --first-only --tabs=4";
        clean = "${pkgs.coreutils}/bin/expand -i --tabs=4";
      };
      diff = {
        sopsdiffer.textconv = "sops --config /dev/null -d";
      };
      advice = {
        skippedCherryPicks = false;
      };
      status = {
        showStash = true;
      };
      stash = {
        showPatch = true;
      };
    };
  };
  home.packages = with pkgs; mkIf config.programs.git.enable [
    git-fixup
    git-continue
    (mkIf (!config.home.minimalSystem) (zsh-plugins.git-completion.override {
      git = config.programs.git.package;
    }))
  ];
  home.shell.aliases = mkIf config.programs.git.enable {
    gcont = "git continue";
    gabort = "git continue --abort";
    gskip = "git continue --skip";
    ga = "git add -p";
    gA = "git add";
    gfe = "git fetch --all";
    gf = "git fixup";
    gb = "git branch";
    gc = "git commit";
    gcp = "git cherry-pick";
    gcm = "git commit -m";
    gch = "git checkout";
    gchp = "git checkout -p";
    gcb = "git checkout -b";
    gcfe = "git config-email";
    ge = "git revise -c";
    gedit = "git revise -e";
    gd = "git diff";
    gds = "git diff --staged";
    gdv = "git difftool -t vimdiff -y";
    gm = "git merge";
    gmv = "git mv";
    gp = "git push";
    gpu = "git push -u";
    gpf = "git push -f";
    gpull = "git pull";
    gpullu = "git pull --set-upstream";
    gr = "git reset";
    grh = "git reset --hard";
    grb = "git rebase";
    grbi = "git rebase -i";
    grm = "git rm";
    grmc = "git rm --cached";
    grv = "git revert";
    gs = "git status -s";
    gsh = "git show";
    gpush = "git stash";
    gpop = "git stash pop";
    gl = "git logs";
    gt = "git tag";
  };
}
