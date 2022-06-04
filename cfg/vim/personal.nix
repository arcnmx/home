{ config, pkgs, lib, ... } @ args: with lib; let
  vimSettings = ''
    let g:Hexokinase_ftDisabled = ['notmuch-search']
    let g:Hexokinase_ftEnabled = ['html', 'css'] " TODO: not worth configuring properly right now
    let g:echodoc#enable_at_startup=1
    set statusline^=%{FugitiveStatusline()}
  '';
  vimPlugins = with pkgs.vimPlugins; [
    editorconfig-vim
    vim-easymotion
    vim-fugitive
    vim-hexokinase
    jsonc-vim
    echodoc-vim
  ];
in {
  imports = [
    ./asciidoc.nix
    ./notmuch.nix
    ./coc.nix
  ];

  programs.vim = {
    plugins = vimPlugins;
    extraConfig = vimSettings;
  };
  programs.neovim = {
    enable = true;
    plugins = vimPlugins;
    extraConfig = ''
      ${vimSettings}

      let g:echodoc#type = 'floating'
    '';
  };
}
