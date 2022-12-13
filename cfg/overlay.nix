self: super: {
  zsh = super.zsh.overrideAttrs (old: {
    patches = old.patches or [ ] ++ [
      ./shell/zsh-globquote.patch
    ];
  });
  zshVanilla = super.zsh;
}
