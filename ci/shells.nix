{
  default = { mkShell, inetutils }: let
    hostname = pkgs.writeShellScriptBin "hostname" ''
      exec ${inetutils}/bin/hostname "$@"
    '';
    # TODO: config = import ./default.nix { };
  in mkShell {
    nativeBuildInputs = [ hostname ] /*++ config.runners.lazy.nativeBuildInputs*/;

    # TODO: HISTFILE = toString (config.deploy.dataDir + "/.history");

    shellHook = ''
      export HOME_HOSTNAME=$(hostname -s)
      export HOME_UID=$(id -u)
      export HOME_USER=$(id -un)
    '';
  };
}
