{ config, lib, ... }: with lib; {
  config = {
    extern.entries.github-access = {
      bitw.name = "github-public-access";
    };
  };
}
