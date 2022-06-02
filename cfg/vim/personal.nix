{ config, pkgs, lib, ... } @ args: with lib; let
  vimSettings = ''
    let g:Hexokinase_ftDisabled = ['notmuch-search']
    let g:Hexokinase_ftEnabled = ['html', 'css'] " TODO: not worth configuring properly right now
    let g:echodoc#enable_at_startup=1
    set statusline^=%{FugitiveStatusline()}
  '' + optionalString (!config.home.minimalSystem) ''
    function M2A()
      :%!${pkgs.pandoc}/bin/pandoc --columns=120 --wrap=preserve -f gfm+hard_line_breaks -t asciidoctor
      :set ft=asciidoc
    endfunction
    function A2M()
      " workaround for https://github.com/jgm/pandoc/issues/8011
      :%!${pkgs.asciidoctor}/bin/asciidoctor -b docbook5 - | sed -e 's/10063;/9744;/' -e 's/10003;/9746;/g' | ${pkgs.pandoc}/bin/pandoc --columns=120 --wrap=none -f docbook -t gfm+hard_line_breaks | sed -e 's/^-   /- /'
      :set ft=markdown
    endfunction
    command M2A call M2A()
    command A2M call A2M()
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
