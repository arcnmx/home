{ config, pkgs, lib, ... } @ args: with lib; let
  shell = package: command: ''nix shell nixpkgs-big\\#${package} -c ${package} ${command} 2>/dev/null''; # ${pkgs.${package}}
  pandoc = shell "pandoc";
  asciidoctor = shell "asciidoctor";
  replacements = [
    ''s/&#8217;\(s\|ll\|re\|m\|d\|t\|ve\)\b/\&#700;\1/g'' # U+2019 in contractions to U+02BC
  ] ++ optionals (versionOlder pkgs.pandoc.version "2.18.1") [
    # workaround for https://github.com/jgm/pandoc/issues/8011
    ''s/10063;/9744;/''
    ''s/10003;/9746;/g''
  ];
  replacementExprs = map (r: "-e ${escapeShellArg r}") replacements;
  filterAdocOutput = pkgs.writeShellScript "filter-asciidoctor.sh" ''
    sed ${concatStringsSep " " replacementExprs}
  '';
  compactLists = shell "xmlstarlet" ''ed -i //_:itemizedlist -t attr -n spacing -v compact -i //_:orderedlist -t attr -n spacing -v compact'' + " |";
  vimSettings = mkIf (!config.home.minimalSystem) ''
    function M2A()
      if &ft == "markdown"
        execute "%!${pandoc ''--columns=120 --wrap=preserve -f" g:mkdn_format "-t asciidoctor''}"
        set ft=asciidoc
        let g:mkdn=1
      endif
    endfunction
    function A2M()
      if &ft == "asciidoc"
        execute "%!${asciidoctor "-b docbook5 -"} | ${filterAdocOutput} | ${compactLists} ${pandoc ''--columns=120 --wrap=none -f docbook -t" g:mkdn_format "''} | sed -e 's/^-   /- /'"
        set ft=markdown
      endif
    endfunction
    augroup M2A
      au!
      au BufWritePre *.md if g:mkdn | call A2M() | endif
      au BufWritePost *.md if g:mkdn | call M2A() | endif
      au BufWritePre *.txt if g:mkdn | call A2M() | endif
      au BufWritePost *.txt if g:mkdn | call M2A() | endif
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
