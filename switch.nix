{ network ? "gensokyo", hostName, targetHost ? null } @ args: let
  #inherit (builtins.import ./import.nix) import;
  inherit (import ./import.nix) pkgs;
  network' = (import ./network.nix { inherit pkgs; }).${network};
  inherit (network'.network.${hostName}) system config;
  #target = if targetHost != null then targetHost else config.deployment.targetHost or "${config.networking.hostName}.${config.networking.domain}";
  target = if targetHost != null then targetHost else config.deployment.targetHost or "${config.network.wan.${hostName}.address}";
  systemDrv = builtins.unsafeDiscardStringContext system.drvPath;
  systemExpr = "\"(import ${systemDrv})\"";
  commands = rec {
    prelude = ''
      nix build --no-link ${pkgs.nix} ${pkgs.coreutils} ${pkgs.inetutils}
      asRoot() {
        if [[ $(${pkgs.coreutils}/bin/id -u) -ne 0 ]]; then
          sudo "$@"
        else
          "$@"
        fi
      }
    '';
    buildDrv = "${pkgs.nix}/bin/nix build --no-link ${systemExpr}";
    env = "${pkgs.nix}/bin/nix-env -p /nix/var/nix/profiles/system --set ${system}";
    switch = "${pkgs.coreutils}/bin/env NIXOS_INSTALL_BOOTLOADER=1 ${system}/bin/switch-to-configuration switch";
    copy = "${pkgs.nix}/bin/nix copy --substitute --to ssh://${target} ${system}";
    deploy = ''
      ${copy}
      ${pkgs.openssh}/bin/ssh root@${target} '${env} && ${switch}'
    '';
  };
in with commands; {
  inherit system config;

  build = ''#!${pkgs.bash}/bin/sh
    (
      set -e
      ${prelude}
      ${pkgs.nix}/bin/nix build -o result-${network}-${hostName} ${systemExpr}
    )
  '';
  switch = ''#!${pkgs.bash}/bin/sh
    (
      set -e
      ${prelude}
      ${buildDrv}
      if [[ $(${pkgs.inetutils}/bin/hostname -s) = ${hostName} ]]; then
        asRoot ${env}
        asRoot ${switch}
      else
        ${deploy}
      fi
    )
  '';
}
