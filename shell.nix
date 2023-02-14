{ }: let
  config = import ./config { };
  inherit (config) pkgs;
in with pkgs; with lib; let
  hostname = writeShellScriptBin "hostname" ''
    exec ${inetutils}/bin/hostname "$@"
  '';
in mkShell {
  nativeBuildInputs = config.runners.lazy.nativeBuildInputs;

  HISTFILE = toString (config.deploy.dataDir + "/.history");

  shellHook = ''
    export HOME_HOSTNAME=$(${getExe hostname} -s)
    export HOME_UID=$(id -u)
    export HOME_USER=$(id -un)
    export SSH_AUTH_SOCK=/run/user/$HOME_UID/gnupg/S.gpg-agent.ssh
    export NIX_PATH="$NIX_PATH:home=${toString ./config}"
    export CI_PLATFORM=impure
  '';
}
