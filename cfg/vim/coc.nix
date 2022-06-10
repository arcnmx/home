{ config, pkgs, lib, ... } @ args: with lib; let
  vimCocSettings = ''
    source ${./vimrc-coc}
    let g:coc_node_path='${pkgs.nodejs}/bin/node'
  '';
  vimCocPlugins = with pkgs.vimPlugins; [
    coc-json
    coc-yaml
    coc-rust-analyzer
    coc-git
    coc-yank
    coc-tsserver
    coc-lua
    coc-pyright
    coc-spell-checker
    coc-smartf
    coc-markdownlint
    coc-cmake
    coc-html coc-css
    coc-explorer
    coc-lists
  ];
in {
  programs.vim = {
    plugins = mkIf config.programs.neovim.coc.enable (
      singleton pkgs.vimPlugins.coc-nvim ++ vimCocPlugins
    );
    extraConfig = mkIf config.programs.neovim.coc.enable ''
      ${vimCocSettings}
      let g:coc_config_home=$XDG_CONFIG_HOME . '/vim/coc'
    '';
  };
  programs.neovim = {
    plugins = mkIf config.programs.neovim.coc.enable vimCocPlugins;
    extraConfig = mkIf config.programs.neovim.coc.enable vimCocSettings;
    coc = {
      enable = mkDefault (!config.home.minimalSystem);
      settings = {
        languageserver = {
          efm = {
            command = "${pkgs.efm-langserver}/bin/efm-langserver";
            args = [];
            filetypes = [ "vim" ];
          };
          nix = {
            command = "${pkgs.rnix-lsp}/bin/rnix-lsp";
            args = [];
            filetypes = ["nix"];
            cwd = "./";
            initializationOptions = {
            };
            settings = {
            };
          };
        };
        "coc.preferences.extensionUpdateCheck" = "never";
        #"coc.preferences.watchmanPath" = "${pkgs.watchman}/bin/watchman"; # TODO: segfaults constantly, see https://github.com/NixOS/nixpkgs/issues/156177
        "suggest.timeout" = 1000;
        "suggest.maxPreviewWidth" = 120;
        "suggest.enablePreview" = true;
        "suggest.echodocSupport" = true;
        "suggest.minTriggerInputLength" = 2;
        "suggest.acceptSuggestionOnCommitCharacter" = true;
        "suggest.snippetIndicator" = "►";
        "diagnostic.checkCurrentLine" = true;
        "diagnostic.enableMessage" = "jump";
        "diagnostic.virtualText" = true;
        "list.nextKeymap" = "<A-j>";
        "list.previousKeymap" = "<A-k>";
        # list.normalMappings, list.insertMappings
        # coc.preferences.formatOnType, coc.preferences.formatOnSaveFiletypes
        "npm.binPath" = "${pkgs.coreutils}/bin/false"; # whatever it wants npm for, please just don't
        "codeLens.enable" = true;
        "codeLens.position" = "eol";
        "rust-analyzer.server.path" = "rust-analyzer";
        "rust-analyzer.updates.prompt" = "neverDownload";
        "rust-analyzer.notifications.cargoTomlNotFound" = false;
        "rust-analyzer.cargo.runBuildScripts" = true;
        "rust-analyzer.procMacro.enable" = true;
        "rust-analyzer.experimental.procAttrMacros" = true;
        "rust-analyzer.completion.addCallParenthesis" = true; # consider using this?
        "rust-analyzer.hover.linksInHover" = true;
        "rust-analyzer.rustfmt.enableRangeFormatting" = true;
        "rust-analyzer.lens.methodReferences" = true;
        "rust-analyzer.assist.allowMergingIntoGlobImports" = false;
        "rust-analyzer.diagnostics.disabled" = [
          "inactive-code" # it has strange cfg support..?
        ];
        # NOTE: per-project overrides go in $PWD/.vim/coc-settings.json
      };
    };
  };
  xdg.configFile = {
    "efm-langserver/config.yaml".text = ''
      languages:
        markdown:
          lint-command: '${pkgs.nodePackages.markdownlint-cli}/bin/markdownlint -s'
          lint-stdin: true
          lint-formats:
          - '%f: %l: %m'
        vim:
          lint-command: '${pkgs.vim-vint}/bin/vint -'
          lint-stdin: true
        yaml:
          lint-command: '${pkgs.yamllint}/bin/yamllint -f parsable -'
          lint-stdin: true
          lint-formats:
          - '%f:%l:%c: %m'
    '';
    "vim/coc/coc-settings.json" = mkIf (config.programs.vim.enable && config.programs.neovim.coc.enable) {
      text = builtins.toJSON config.programs.neovim.coc.settings;
    };
  };
}
