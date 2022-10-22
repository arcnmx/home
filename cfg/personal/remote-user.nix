{ config, lib, ... }: with lib; {
  users.users.remote = {
    isNormalUser = true;
    createHome = true;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFDvSC7C8GcDLEbuCYH3MlPkMQQAO6NnUlWdBaIYpP6E Shortcuts on iPhone SE"
    ];
  };
}
