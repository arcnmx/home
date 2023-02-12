{ config, lib, ... } @ args: with lib; {
  programs.syncplay = {
    enable = true;
    username = "arc";
    defaultRoom = "lounge";
    gui = false;
    trustedDomains = [ "youtube.com" "youtu.be" "twitch.tv" "soundcloud.com" ];
    playerArgs = singleton ''--ytdl-format=bestvideo[height<=?1080]+bestaudio/best[height<=?1080]/bestvideo+bestaudio/best'';
    config = {
      client_settings = {
        autoplayrequiresamefiles = false;
        readyatstart = true;
        pauseonleave = false;
        rewindondesync = false;
        rewindthreshold = 6.0;
        fastforwardthreshold = 6.0;
        unpauseaction = "Always";
      };
      gui = {
        #autosavejoinstolist = false;
        showdurationnotification = false;
        chatoutputrelativefontsize = config.lib.gui.size 10 { float = true; };
      };
    };
  };
}
