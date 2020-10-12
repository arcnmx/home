{ }: let
  toplevel = import ./default.nix { };
  inherit (toplevel) pkgs;
in pkgs.mkShell {
  nativeBuildInputs = with pkgs; [ inetutils ];

  HISTFILE = toString (toplevel.deploy.dataDir + "/.history");

  shellHook = ''
    export HOME_HOSTNAME=$(hostname -s)
    export HOME_UID=$(id -u)
  '';
}
