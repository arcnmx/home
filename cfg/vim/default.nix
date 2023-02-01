{ nixosConfig, config, pkgs, lib, ... } @ args: with lib; let
  vimPlugins = with pkgs.vimPlugins; [
    vim-cool
    vim-ledger
    vim-dispatch
    vim-lastplace
    vim-commentary
    vim-surround
    vim-toml
    kotlin-vim
    swift-vim
    rust-vim
    vim-nix
    vim-osc52
  ];
in {
  imports = [
    ./page.nix
  ];

  xdg.configFile = mkIf config.programs.vim.enable {
    "vim/after/indent/rust.vim".text = ''
      setlocal comments=s0:/*!,m:\ ,ex:*/,s0:/*,mb:\ ,ex:*/,:///,://!,://
    '';
    "vim/after/indent/nix.vim".text = ''
      setlocal indentkeys=0{,0},0),0],:,0#,!^F,o,O,e,0=then,0=else,0=inherit,*<Return>
    '';
    "vim/after/indent/yaml.vim".text = ''
      setlocal indentkeys=!^F,o,O,0},0]
      set tabstop=2
      set softtabstop=2
      set shiftwidth=2
      set expandtab
    '';
  };
  xdg.dataDirs = mkIf config.programs.vim.enable [
    "vim/undo"
    "vim/swap"
    "vim/backup"
  ];
  home.sessionVariables = mkMerge [
    (mkIf config.programs.neovim.enable {
      EDITOR = "nvim";
    })
    (mkIf (config.programs.vim.enable && !config.programs.neovim.enable) {
      EDITOR = "${config.programs.vim.package}/bin/vim";
    })
  ];

  programs.vim = {
    enable = mkDefault (!config.programs.neovim.enable);
    plugins = vimPlugins;
    settings = {};
    extraConfig = mkMerge [ (mkBefore ''
      let base16background='none' " activate patch to disable solid backgrounds
    '') ''
      source ${./vimrc-vim}
      source ${./vimrc}
      source ${./vimrc-keys}
    '' ];
    packageConfigurable = if config.home.minimalSystem
      then pkgs.vim_configurable.override {
        guiSupport = "no";
        luaSupport = false;
        multibyteSupport = true;
        ftNixSupport = false;
      } else pkgs.vim_configurable-pynvim;
  };
  programs.neovim = {
    enable = mkDefault (nixosConfig.deploy.personal.enable || config.home.minimalSystem);
    vimAlias = !config.programs.vim.enable;
    vimdiffAlias = true;
    plugins = vimPlugins;
    extraConfig = mkMerge [ (mkBefore ''
      let base16background='none' " activate patch to disable solid backgrounds
    '') ''
      source ${./vimrc}
      source ${./vimrc-keys}
      source ${./vimrc-nvim.lua}
    '' ];
  };
}
