{ config, pkgs, lib, ... }: with lib; {
  key = "NVIDIA GPU";

  config = {
    services.picom = {
      backend = "xrender";
      extraOptions = ''
        unredir-if-possible = true;
      '';
    };
    services.polybar = {
      config = {
        "bar/base" = {
          modules-right = mkOrder 1260 [ "gpu" ];
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
        query = pkgs.writeShellScriptBin "query" ''
          set -eu
          set -o pipefail

          export PATH=$PATH:${path}

          CSV=$(nvidia-smi -i 0 --format=csv,noheader,nounits --query-gpu=memory.used,memory.total,utilization.gpu,fan.speed 2> /dev/null | tr -d ' ')
          MEM_USED=$(printf %s "$CSV" | cut -d, -f1)
          MEM_TOTAL=$(printf %s "$CSV" | cut -d, -f2)
          UTIL=$(printf %s "$CSV" | cut -d, -f3)
          FAN=$(printf %s "$CSV" | cut -d, -f4)

          MEM_PERCENT=$((MEM_USED * 100 / MEM_TOTAL))

          printf "%d%% %d MiB %d%%" $UTIL $MEM_USED $MEM_PERCENT
        '';
      in {
        "module/gpu" = {
          type = "custom/script";
          exec = "${query}/bin/query";
          format = "📺 <label>";
          interval = 30;
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
