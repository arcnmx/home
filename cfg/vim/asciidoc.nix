{ config, pkgs, lib, ... } @ args: with lib; let
  pandoc = ''nix shell nixpkgs-big\\#pandoc -c pandoc''; # "${pkgs.pandoc}/bin/pandoc";
  asciidoctor = ''nix shell nixpkgs-big\\#asciidoctor -c asciidoctor''; # "${pkgs.asciidoctor}/bin/asciidoctor";
  filterTasklist = optionalString (versionOlder pkgs.pandoc.version "2.18.1") # workaround for https://github.com/jgm/pandoc/issues/8011
    "sed -e 's/10063;/9744;/' -e 's/10003;/9746;/g' |";
  vimSettings = mkIf (!config.home.minimalSystem) ''
    function M2A()
      if &ft == "markdown"
        execute "%!${pandoc} --columns=120 --wrap=preserve -f" g:mkdn_format "-t asciidoctor"
        set ft=asciidoc
        let g:mkdn=1
      endif
    endfunction
    function A2M()
      if &ft == "asciidoc"
        execute "%!${asciidoctor} -b docbook5 - | ${filterTasklist} ${pandoc} --columns=120 --wrap=none -f docbook -t" g:mkdn_format "| sed -e 's/^-   /- /'"
        set ft=markdown
      endif
    endfunction
    augroup M2A
      au!
      au BufWritePre *.md if g:mkdn | A2M | endif
      au BufWritePost *.md if g:mkdn | M2A | endif
      au BufWritePre *.txt if g:mkdn | A2M | endif
      au BufWritePost *.txt if g:mkdn | M2A | endif
    augroup END
    command M2A set ft=markdown | call M2A()
    command A2M call A2M()
    command GHC let g:mkdn_format="gfm+hard_line_breaks" | M2A
    let g:mkdn=0
    let g:mkdn_format="gfm"
  '';
in {
  programs.vim.extraConfig = vimSettings;
  programs.neovim.extraConfig = vimSettings;
}
