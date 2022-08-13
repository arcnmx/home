{ config, pkgs, lib, ... } @ args: with lib; {
  programs.page = {
    enable = !config.home.minimalSystem && config.programs.neovim.enable;
    manPager = true;
    queryLines = 80000; # because of how nvim terminal treats long lines (it breaks lines instead of wrapping them), this can go over
    openLines = {
      enable = true;
      promptHeight = 2;
    };
  };
  programs.neovim = {
    extraConfig = ''
      source ${./vimrc-page.lua}
    '';
  };
  xdg.configFile = mkIf config.programs.vim.enable {
    "vim/vimpagerrc" = mkIf config.programs.vim.enable {
      source = ./vimrc-vimpager;
    };
  };
  home.sessionVariables = mkMerge [
    (mkIf (!config.programs.page.enable && config.programs.vim.enable) {
      PAGER = "${pkgs.vimpager-latest}/bin/vimpager";
    })
    (mkIf (!config.programs.page.enable && !config.programs.vim.enable) {
      PAGER = "${pkgs.less}/bin/less";
    })
  ];
}
