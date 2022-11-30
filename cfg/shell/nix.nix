{ nixosConfig, config, pkgs, lib, ... }: with lib; {
  config.home.shell = {
    aliases = {
      nprp = if nixosConfig.nix.isNix24 && elem "repl-flake" nixosConfig.nix.experimentalFeatures
        then "nix repl nixpkgs"
        else "nix repl -f '<nixpkgs>'";
      npath = "nix build --no-link --print-out-paths";
      necho = "nix eval --raw";
      njson = "nix eval --json";
      nup = "nix flake update";
      nupi = "nix flake lock --update-input";
      nb = "nix build";
      nr = "nix run";
      nrp = "nix repl";
      ns = "nix shell";
      nd = "nix develop";
    };
    functions = let
      collectArgs = ''
        local ARGS=()
        while [[ "''${1-}" = -* ]]; do
          ARGS+=("$1")
          shift
        done
      '';
      args = ''"''${ARGS[@]}"'';
    in {
      # helper for use with `nix -I $(nixpkgs unstable)`
      nixpkgs = ''
        echo "nixpkgs=https://nixos.org/channels/$1/nixexprs.tar.xz"
      '';
      ncheck = ''
        ${collectArgs}
        if [[ $# -eq 0 ]] || [[ "$1" != *#* ]]; then
          nix flake check ${args} "$@"
        else
          CHECK="$1"
          shift
          CHANNEL="$(cut -d'#' -f1 <<<"$CHECK")"
          CHECK="$(cut -d'#' -f2- <<<"$CHECK")"
          if [[ -n "$CHECK" ]]; then
            nix build ${args} --show-trace -L "$CHANNEL"#checks.${pkgs.system}."$CHECK" "$@"
          else
            nix flake check ${args} --show-trace "$CHANNEL" "$@"
          fi
        fi
      '';
      nrun = ''
        ${collectArgs}
        if [[ $# -eq 0 ]]; then
          nix run ${args} "$@"
        else
          local CHANNEL=nixpkgs
          local PROG="$1"
          shift

          if [[ $PROG = *#* ]]; then
            CHANNEL="$(cut -d'#' -f1 <<<"$PROG")"
            PROG="$(cut -d'#' -f2- <<<"$PROG")"
          elif [[ $PROG = *.* ]]; then
            # not a flake but close enough...
            CHANNEL="$(cut -d'.' -f1 <<<"$PROG")"
            PROG="$(cut -d'.' -f2 <<<"$PROG")"
          fi

          nix run ${args} "''${CHANNEL}#''${PROG}" -- "$@"
        fi
      '';
      nrpf = ''
        ${collectArgs}
        if [[ $# -eq 0 ]]; then
          local FILE="''${1-.}"
          if [[ $# -gt 0 ]]; then
            shift
          fi

          nix repl ${args} --show-trace -f "$FILE" "$@"
        else
          nix repl ${args} --show-trace "$@"
        fi
      '';
    };
  };
}
