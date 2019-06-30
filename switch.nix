{ network ? "gensokyo", hostName, targetHost ? null } @ args: let
  inherit (import ./import.nix) pkgs;
  network' = (import ./network.nix { inherit pkgs network; }).network;
  inherit (network'.${hostName}) system config;
  #target = if targetHost != null then targetHost else config.deployment.targetHost or "${config.networking.hostName}.${config.networking.domain}";
  target = if targetHost != null then targetHost else config.deployment.targetHost or "${config.network.wan.${hostName}.address}";
  commands = rec {
    prelude = ''
      nix build --no-link ${pkgs.nix} ${pkgs.coreutils} ${pkgs.inetutils}
      asRoot() {
        if [[ $(${pkgs.coreutils}/id -u) -ne 0 ]]; then
          sudo "$@"
        else
          "$@"
        fi
      }
    '';
    buildDrv = "${pkgs.nix}/bin/nix build --no-link ${builtins.unsafeDiscardStringContext system.drvPath}";
    env = "${pkgs.nix}/bin/nix-env -p /nix/var/nix/profiles/system --set ${system}";
    switch = "NIXOS_INSTALL_BOOTLOADER=1 ${system}/bin/switch-to-configuration switch";
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
      ${buildDrv}
      ${pkgs.nix}/bin/nix build -o result-${network}-${hostName} ${system}
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
