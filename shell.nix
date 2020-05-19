{ }: let
  toplevel = import ./import.nix;
  inherit (toplevel) pkgs;
in pkgs.mkShell {
  nativeBuildInputs = with pkgs; [ inetutils ];
  shellHook = ''
    export HOME_HOSTNAME=$(hostname -s)
  '';
}
