{ config, lib, ... }: with lib; let
  userdata = importJSON ./userdata.json;
  mapDefaults = mapAttrs (_: mkDefault);
in {
  config = {
    users.users.kat = mapDefaults {
      uid = 1009;
      isNormalUser = true;
      group = "users";
      createHome = true;
      home = "/home/kat";
    } // {
      openssh.authorizedKeys = mapDefaults userdata.openssh.authorizedKeys;
    };
  };
}
