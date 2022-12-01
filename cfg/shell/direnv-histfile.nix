{ config, lib, ... }: with lib; {
  programs.zsh.initExtra = mkIf config.programs.direnv.enable ''
    _ZSH_HISTFILE=("$HISTFILE")
    chpwd_functions=(''${chpwd_functions[@]} _direnv_check_histfile)
    _direnv_check_histfile() {
      if [[ "$HISTFILE" != "''${_ZSH_HISTFILE[1]}" ]]; then
        local NEW_HISTFILE="$HISTFILE"
        HISTFILE="''${_ZSH_HISTFILE[1]}"
        if [[ -z "$NEW_HISTFILE" ]] || [[ "$NEW_HISTFILE" == "''${_ZSH_HISTFILE[2]-}" ]]; then
          if [[ ''${#_ZSH_HISTFILE[@]} -gt 1 ]] || [[ -n "$NEW_HISTFILE" ]]; then
            echo "histfile: popping from ''${_ZSH_HISTFILE[*]}" >&2
            shift _ZSH_HISTFILE
            fc -P
          else
            echo 'histfile: why is $HISTFILE empty?' >&2
            fc -IR
          fi
        else
          echo "histfile: pushing $NEW_HISTFILE onto ''${_ZSH_HISTFILE[*]}" >&2
          _ZSH_HISTFILE=("$NEW_HISTFILE" "''${_ZSH_HISTFILE[@]}")
          if [[ -n ''${DIRENV_DIR-} ]]; then
            fc -p "$NEW_HISTFILE"
          else
            # ignore changes by user or manual use of `fc`
            HISTFILE="$NEW_HISTFILE"
          fi
        fi
      fi
    }
  '';
}
