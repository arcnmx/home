{ config, lib, ... }: with lib; {
  config = {
    home-manager.users.arc.imports = [ ./home.nix ];

    services.pcscd.enable = mkDefault true;
    services.yubikey-agent.enable = mkDefault true;

    # work around yubikey-agent module
    environment.extraInit = mkAfter ''
      if [[ "$SSH_AUTH_SOCK" = "$XDG_RUNTIME_DIR/yubikey-agent/yubikey-agent.sock" ]]; then
        unset SSH_AUTH_SOCK
      fi
    '';
  };
}
