{ tf, config, pkgs, lib, ... }: with lib; let
  inherit (config.networking) domains bindings;
in {
  config = mkIf config.home.profiles.host.gensokyo {
    services = {
      taskserver = {
        domain = domains.taskserver;
        ipLog = mkDefault true;
        requestLimit = mkDefault (1024*1024*16); # task sync doesn't know how to do things in pieces :<
        organisations.arc.users = singleton "arc";
        pki.manual.ca.cert = pkgs.writeText "taskd.ca.pem" (config.deploy.tf.import.common.resources.taskserver_ca.importAttr "cert_pem");
      };
    };

    networking = {
      bindings.taskserver = {
        address = "*";
        port = mkDefault 53589;
      };
      domains.taskserver = {
        inherit (config.services.taskserver) enable;
        nginx.enable = false;
        enableIPv6 = false;
        bindings.https4 = {
          inherit (bindings.taskserver) port;
        };
        ssl = {
          secret.owner = config.services.taskserver.user;
        };
      };
    };
  };
}
