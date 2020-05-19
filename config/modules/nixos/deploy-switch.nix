{ pkgs, lib, config, ... }: with lib; let
  cfg = config.deploy;
in {
  options.deploy = {
    system = mkOption {
      type = types.unspecified;
      readOnly = true;
    };
    targetHost = mkOption {
      type = types.str;
      default = config.network.wan.${config.networking.hostName}.address;
    };
    run = {
      switch = mkOption {
        type = types.unspecified;
        readOnly = true;
      };
      deploy = mkOption {
        type = types.unspecified;
        readOnly = true;
      };
    };
  };
  config.deploy = {
    system = config.system.build.toplevel;
    run = with pkgs; {
      switch = nixRunWrapper {
        package = writeShellScriptBin "switch" ''
          set -eu
          export NIXOS_INSTALL_BOOTLOADER=1

          asRoot() {
            if [[ $(${pkgs.coreutils}/bin/id -u) -ne 0 ]]; then
              sudo "$@"
            else
              "$@"
            fi
          }

          if [[ $(${pkgs.inetutils}/bin/hostname -s) != ${config.networking.hostName} ]]; then
            echo "switch must run on ${config.networking.hostName}" >&2
            exit 1
          fi

          asRoot ${pkgs.nix}/bin/nix-env -p /nix/var/nix/profiles/system --set ${cfg.system}
          asRoot ${cfg.system}/bin/switch-to-configuration switch
        '';
      };
      deploy = nixRunWrapper {
        package = writeShellScriptBin "deploy" ''
          set -eu

          if [[ $(${pkgs.inetutils}/bin/hostname -s) = ${config.networking.hostName} ]]; then
            ${cfg.run.switch}/bin/switch
          else
            ${pkgs.nix}/bin/nix copy --substitute --to ssh://${config.deploy.targetHost} ${cfg.run.switch}
            ${pkgs.openssh}/bin/ssh ${config.deploy.targetHost} ${cfg.run.switch}/bin/switch
          fi
        '';
      };
    };
  };
}
