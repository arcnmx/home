{ config, pkgs, lib, nixosConfig, ... }: with lib; let
  pactl = "${nixosConfig.hardware.pulseaudio.package}/bin/pactl";
in {
  key = "shanghai";

  imports = [ ./screenstub.nix ./patoggle.nix ];

  config = {
    accounts.email.enableSync = true;

    home.packages = [
      pkgs.paswitch
    ];
    services.konawall = {
      commonTags = [ "width:>=1600" ];
      tags = [ "score:>=200" "rating:safe" ];
    };
    services.polybar.settings = {
      "module/fs-root" = {
        mount = mkAfter [ "/mnt/enc" "/nix" "/mnt/data" ];
      };
    };
    services.dunst.iconTheme.size = "64x64";
    home.shell.functions = {
      _paswitch_sinks = ''
        ${pactl} list short sinks | ${pkgs.coreutils}/bin/cut -d $'\t' -f 2
      '';
      _paswitch = ''
        _alternative 'preset:preset:(headphones speakers)' 'sink:sink:($(_paswitch_sinks))'
      '';
      ryzen-watch = ''
        sudo watch -ctn1 'ryzen_monitor -u0'
      '';
    };
    home.scratch.enable = true;
    programs.zsh.initExtra = ''
      compdef _paswitch paswitch
    '';
    # workaround for https://github.com/neovim/neovim/issues/12075
    programs.neovim.extraConfig = mkAfter ''
      set shada+=r/mnt/wdarchive
      set shada+=r/mnt/wdworking
      set shada+=r/mnt/wdmisc
    '';
    hardware.display = mapAttrs (k: v: {
      nvidia.enable = mkDefault nixosConfig.hardware.display.nvidia.enable;
      monitors = v config.hardware.display.${k}.monitors;
    }) (import ./displays.nix { inherit lib; }).monitors;
    xsession.windowManager.i3 = with nixosConfig.hardware.display.monitors; {
      extraConfig = ''
        workspace 1:1 output ${dell.output}
        workspace 2:2 output ${spectrum.output}
        workspace 3:3 output ${lg.output}

        workspace 11:F1 output ${dell.output}
        workspace 12:F2 output ${spectrum.output}
      '';
      config = {
        assigns = {
          "number 11:F1" = [
            { class = "^screenstub$"; instance = "Dell"; }
          ];
          "number 12:F2" = [
            { class = "^screenstub$"; instance = "Spectrum"; }
          ];
        };
      };
    };
    services.mpd = {
      extraConfig = ''
        samplerate_converter "1"

        audio_output {
          type "httpd"
          name "httpd-high"
          encoder "opus"
          bitrate "96000"
          port "32101"
          max_clients "4"
          format "48000:16:2"
          always_on "yes"
          tags "yes"
        }

        audio_output {
          type "httpd"
          name "httpd-low"
          encoder "opus"
          bitrate "58000"
          port "32102"
          max_clients "4"
          format "48000:16:2"
          always_on "yes"
          tags "yes"
        }
      '';
    };
    programs.mpv = {
      config = {
        # may as well use the excess RAM for something
        demuxer-max-bytes = "2000MiB";
        demuxer-max-back-bytes = "250MiB";
      };
    };
  };
}
