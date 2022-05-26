{ }: let
  config = import ./config { };
  inherit (config) pkgs;
  hostname = pkgs.writeShellScriptBin "hostname" ''
    exec ${pkgs.inetutils}/bin/hostname "$@"
  '';
in pkgs.mkShell {
  nativeBuildInputs = with pkgs; [ hostname ] ++ config.runners.lazy.nativeBuildInputs;

  HISTFILE = toString (config.deploy.dataDir + "/.history");

  shellHook = ''
    export HOME_HOSTNAME=$(hostname -s)
    export HOME_UID=$(id -u)
    export HOME_USER=$(id -un)
    export NIX_PATH="$NIX_PATH:home=${toString ./config}"
  '';
}
