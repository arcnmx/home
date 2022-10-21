{ config, lib, ... }: with lib; let
in {
  config = {
    home-manager.users.arc.imports = [ ./home.nix ];
    deploy.tf = {
      resources = {
        mpd_password_admin = {
          provider = "random";
          type = "password";
          inputs = {
            length = 16;
            special = false;
          };
        };
      };
    };
  };
}
