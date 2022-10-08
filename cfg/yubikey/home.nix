{ config, lib, ... }: with lib; {
  config = {
    services.gpg-agent.enableScDaemon = true;
  };
}
