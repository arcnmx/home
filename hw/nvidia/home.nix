{ config, pkgs, lib, ... }: with lib; let
  polycfg = config.services.polybar.nvidia;
in {
  key = "NVIDIA GPU";

  options = with types; {
    services.polybar.nvidia = {
      enable = mkEnableOption "nvidia bar" // {
        default = true;
      };
      tail = mkOption {
        type = bool;
        default = true;
        description = "seconds";
      };
      interval = mkOption {
        type = int;
        default = 30;
        description = "seconds";
      };
      break = mkOption {
        type = int;
        default = 10;
        description = "every X intervals";
      };
      gpu = mkOption {
        type = str;
        default = "0";
        example = "GPU-3dabcdef-a123-b123-c123-abcd12345678";
      };
    };
  };

  config = {
    services.picom = {
      backend = "xrender";
      settings.unredir-if-possible = true;
    };
    services.polybar = {
      config = {
        "bar/base" = {
          modules-right = mkIf polycfg.enable (mkOrder 1260 [ "gpu" ]);
        };
      };
      settings = let
        smi = "${config.home.nixosConfig.hardware.nvidia.package.bin}/bin/nvidia-smi";
        path = makeBinPath (
          singleton pkgs.coreutils
          ++ optional (config.home.nixosConfig ? hardware.nvidia.package)
            config.home.nixosConfig.hardware.nvidia.package.bin
        );
        # could support multiple GPUs, also use `--loop` for tail-style output
        query = pkgs.writeShellScriptBin "nv-query" ''
          set -eu
          set -o pipefail
          shopt -s lastpipe

          export PATH=$PATH:${path}

          COUNT=0
          nvidia-smi \
            --id=${polycfg.gpu} \
            ${optionalString polycfg.tail "--loop=${toString polycfg.interval}"} \
            --format=csv,noheader,nounits \
            --query-gpu=memory.used,memory.total,utilization.gpu,fan.speed \
            2> /dev/null |
          while read -rt ${toString (polycfg.interval * 2)} CSV; do
            if ! [[ $CSV = *,* ]]; then
              echo "$CSV" >&2
              break 1
            fi
            CSV=$(echo "$CSV" | tr -d ' ')

            MEM_USED=$(printf %s "$CSV" | cut -d, -f1)
            MEM_TOTAL=$(printf %s "$CSV" | cut -d, -f2)
            UTIL=$(printf %s "$CSV" | cut -d, -f3)
            FAN=$(printf %s "$CSV" | cut -d, -f4)

            MEM_PERCENT=$((MEM_USED * 100 / MEM_TOTAL))

            printf "%d%% %d MiB %d%%\n" $UTIL $MEM_USED $MEM_PERCENT

            COUNT=$((COUNT+1))
            if [[ $COUNT -gt ${toString polycfg.break} ]]; then
              exit 0
            fi
          done
        '';
      in {
        "module/gpu" = mkIf polycfg.enable {
          type = "custom/script";
          exec = getExe query;
          tail = polycfg.tail;
          interval = polycfg.interval;
          format = "📺 <label>";
        };
      };
    };
    programs.mpv = {
      config = {
        hwdec = "cuda";

        profile = "gpu-hq";
      };
    };
  };
}
