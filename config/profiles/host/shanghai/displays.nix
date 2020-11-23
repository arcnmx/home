{ lib }: with lib; rec {
  monitors = {
    stacked = monitors: with monitors; {
      benq = { config, ... }: {
        output = "DP-0";
        xserver.sectionName = "Monitor[1]";
        nvidia.options.AllowGSYNCCompatible = mkIf (hasPrefix "DP-" config.output) "On";
        width = 2560;
        height = 1440;
        x = lg.x - config.viewport.width;
        y = dell.y - config.viewport.height;
      };
      dell = { config, ... }: {
        output = "HDMI-0";
        xserver.sectionName = "Monitor[0]";
        nvidia.options.AllowGSYNCCompatible = mkIf (hasPrefix "DP-" config.output) "On";
        primary = true;
        width = 3840;
        height = 2160;
        x = 0;
        y = lg.viewport.height - config.viewport.height;
      };
      lg = { config, ... }: {
        output = "DP-2";
        xserver.sectionName = "Monitor[2]";
        nvidia.options.AllowGSYNCCompatible = mkIf (hasPrefix "DP-" config.output) "On";
        rotation = "right";
        width = 3840;
        height = 2160;
        x = dell.x + dell.viewport.width;
        y = 0;
      };
    };
    linear = monitors: with monitors; {
      benq = { config, ... }: {
        output = "DP-0";
        xserver.sectionName = "Monitor[1]";
        nvidia.options.AllowGSYNCCompatible = mkIf (hasPrefix "DP-" config.output) "On";
        width = 2560;
        height = 1440;
        x = 0;
        y = dell.y + dell.viewport.height - config.viewport.height;
      };
      dell = { config, ... }: {
        output = "HDMI-0";
        xserver.sectionName = "Monitor[0]";
        nvidia.options.AllowGSYNCCompatible = mkIf (hasPrefix "DP-" config.output) "On";
        primary = true;
        width = 3840;
        height = 2160;
        x = benq.x + benq.viewport.width;
        y = lg.viewport.height - config.viewport.height;
      };
      lg = { config, ... }: {
        output = "DP-2";
        xserver.sectionName = "Monitor[2]";
        nvidia.options.AllowGSYNCCompatible = mkIf (hasPrefix "DP-" config.output) "On";
        rotation = "right";
        width = 3840;
        height = 2160;
        x = dell.x + dell.viewport.width;
        y = 0;
      };
    };
    gaming = monitors: with monitors; {
      # linear but with benq in the middle
      benq = { config, ... }: {
        output = "DP-0";
        xserver.sectionName = "Monitor[1]";
        nvidia.options.AllowGSYNCCompatible = mkIf (hasPrefix "DP-" config.output) "On";
        width = 2560;
        height = 1440;
        x = dell.x + dell.viewport.width;
        y = dell.y + dell.viewport.height - config.viewport.height;
      };
      dell = { config, ... }: {
        output = "HDMI-0";
        xserver.sectionName = "Monitor[0]";
        nvidia.options.AllowGSYNCCompatible = mkIf (hasPrefix "DP-" config.output) "On";
        primary = true;
        width = 3840;
        height = 2160;
        x = 0;
        y = lg.viewport.height - config.viewport.height;
      };
      lg = { config, ... }: {
        output = "DP-2";
        xserver.sectionName = "Monitor[2]";
        nvidia.options.AllowGSYNCCompatible = mkIf (hasPrefix "DP-" config.output) "On";
        rotation = "right";
        width = 3840;
        height = 2160;
        x = benq.x + benq.viewport.width;
        y = 0;
      };
    };
  };
  default = monitors.stacked;
}
