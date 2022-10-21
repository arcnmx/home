{ meta, tf, pkgs, nixosConfig, config, lib, ... }: with lib; let
  cfg = config.services.mpd;
  inherit (tf) resources;
in {
  imports = [
    ./ncmpcpp.nix
  ];
  secrets.files.mpd-config = mkIf config.services.mpd.enable {
    text = config.services.mpd.configText;
  };
  programs.mpc = {
    enable = mkDefault true;
    servers = {
      shanghai = {
        enable = mkDefault (nixosConfig.networking.hostName != "shanghai");
        connection = {
          address = "shanghai";
          binding = meta.network.nodes.shanghai.networking.bindings.mpd;
        };
      };
      local = mkIf (cfg.enable && tf.state.enable) {
        password = tf.import.common.output.import.exports_sensitive.mpd_password.result;
      };
    };
  };
  services = {
    mpd = {
      enable = true;
      network = {
        startWhenNeeded = true;
        listenAddress = "any";
      };
      package = pkgs.mpd-youtube-dl;
      dbFile = "${cfg.dataDir}/mpd.db";
      musicDirectory = config.xdg.userDirs.absolute.music;
      extraConfig = mkMerge [ ''
        restore_paused "yes"
        metadata_to_use "artist,artistsort,album,albumsort,albumartist,albumartistsort,title,track,name,genre,date,composer,performer,comment,disc,musicbrainz_artistid,musicbrainz_albumid,musicbrainz_albumartistid,musicbrainz_trackid,musicbrainz_releasetrackid"
        auto_update "yes"
        max_output_buffer_size "65536"

        follow_outside_symlinks "yes"
        follow_inside_symlinks "yes"

        default_permissions "read"

        audio_output {
          type "pulse"
          name "speaker"
        }
        input {
          plugin "youtube-dl"
          executable "${pkgs.yt-dlp}/bin/yt-dlp"
        }
      '' (mkIf tf.state.enable ''
        password "${tf.import.common.output.refAttr "outputs.exports_sensitive.mpd_password.result"}@read,add,control"
        password "${resources.mpd_password_admin.refAttr "result"}@read,add,control,admin"
      '') ];
      configPath = mkIf tf.state.enable config.secrets.files.mpd-config.path;
    };
    mpdris2.enable = mkDefault config.services.mpd.enable;
  };
  systemd.user.services.mpdris2 = mkIf config.services.mpdris2.enable {
    Install = mkForce {
      WantedBy = [ "mpd.service" ];
    };
    Unit = {
      PartOf = [ "mpd.service" ];
    };
  };
}
