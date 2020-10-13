{ }: let
  config = import ./default.nix { };
  inherit (config) pkgs;
in with pkgs.lib; let
  indirectPackageAttrs = {
    borg = {
      attr = "deploy.archive.borg.package";
    };
    switch = {
      attr = "switch";
    };
  } // foldAttrList (mapAttrsToList (target: _: {
    "${target}-apply" = {
      bin = "terraform-apply";
      attr = "deploy.targets.${target}.tf.runners.run.apply.package";
    };
    "${target}-tf" = {
      bin = "terraform";
      attr = "deploy.targets.${target}.tf.runners.run.terraform.package";
    };
    "${target}-ssh" = {
      bin = "${target}-ssh";
      attr = "deploy.targets.${target}.tf.runners.run.${target}-ssh.package";
    };
  }) config.deploy.targets);
  indirectPackages = mapAttrsToList (name: value: pkgs.writeShellScriptBin name ''
    exec nix run --quiet --show-trace -f ${toString ./.} ${value.attr} -c ${value.bin or name} "$@"
  '') indirectPackageAttrs;
in pkgs.mkShell {
  nativeBuildInputs = with pkgs; [ inetutils ] ++ indirectPackages;

  HISTFILE = toString (config.deploy.dataDir + "/.history");

  shellHook = ''
    export HOME_HOSTNAME=$(hostname -s)
    export HOME_UID=$(id -u)
  '';
}
