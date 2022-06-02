{ config, pkgs, lib, ... } @ args: with lib; let
  vimNotmuchSettings = ''
    source ${./vimrc-notmuch}
    let g:notmuch_config_file='${config.home.sessionVariables.NOTMUCH_CONFIG}'
    let g:notmuch_html_converter='${pkgs.elinks}/bin/elinks --dump'
    let g:notmuch_attachment_dir='${config.xdg.userDirs.absolute.download}'
    let g:notmuch_view_attachment='xdg-open'
    let g:notmuch_sendmail_method='sendmail'
    let g:notmuch_sendmail_location='${pkgs.msmtp}/bin/msmtp'
    let g:notmuch_open_uri='firefox'
  '';
in {
  home.shell.aliases.mail = mkIf config.programs.notmuch.enable "vim +NotMuch";
  programs.vim = {
    plugins = mkIf config.programs.notmuch.enable [ pkgs.vimPlugins.notmuch-vim ];
    extraConfig = mkIf config.programs.notmuch.enable vimNotmuchSettings;
  };
  programs.neovim = {
    plugins = mkIf config.programs.notmuch.enable [ pkgs.vimPlugins.notmuch-vim ];
    extraConfig = mkIf config.programs.notmuch.enable vimNotmuchSettings;
  };
}
