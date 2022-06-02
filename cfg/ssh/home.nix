{
  programs.ssh = {
    enable = true;
    compression = true;
    controlMaster = "auto";
    #controlPath = "/run/user/%i/%C-%n"; # mine but sometimes gets too long
    #controlPath = "~/.ssh/master-%r@%n:%p"; # default
    controlPersist = "1m";
    serverAliveInterval = 60;
    #PubkeyAcceptedKeyTypes=+ssh-dss # do I still need this?
    extraConfig = ''
      SendEnv=TERM_THEME
    '';
    knownHosts = [
      "satorin ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFgcPU64V9VTwqGZ5GtaqXZd1o/T+58/VXsSfp+nUl6Q"
      "shanghai ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEx8KadgtdeLNmQrEGRqoVE/c5zMMBQ3O7SgAsfTOfZK"
    ];
  };
}
