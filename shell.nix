{ }: let
  config = import ./default.nix { };
  inherit (config) pkgs;
in pkgs.mkShell {
  nativeBuildInputs = with pkgs; [ inetutils ] ++ config.runners.lazy.nativeBuildInputs;

  HISTFILE = toString (config.deploy.dataDir + "/.history");

  shellHook = ''
    export HOME_HOSTNAME=$(hostname -s)
    export HOME_UID=$(id -u)
    export HOME_USER=$(id -un)
    export NIX_PATH="$NIX_PATH:home=${toString ./.}"
  '';
}
