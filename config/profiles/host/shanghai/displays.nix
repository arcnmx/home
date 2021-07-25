{ lib }: with lib; let
  _4k = {
    width = 3840;
    height = 2160;
  };
  defaults = {
    common = { config, ... }: {
      nvidia.options.AllowGSYNCCompatible = mkIf (hasPrefix "DP-" config.output) "On";
    };
    spectrum = { config, ... }: {
      imports = [ defaults.common ];
      output = mkDefault "DP-0";
      xserver.sectionName = mkDefault "Monitor[1]";
      refreshRate = mkDefault 144;
    } // mapAttrs (_: mkDefault) _4k;
    dell = { config, ... }: {
      imports = [ defaults.common ];
      output = mkDefault "HDMI-0";
      xserver.sectionName = mkDefault "Monitor[0]";
      primary = mkDefault true;
    } // mapAttrs (_: mkDefault) _4k;
    lg = { config, ... }: {
      imports = [ defaults.common ];
      output = mkDefault "DP-2";
      xserver.sectionName = mkDefault "Monitor[2]";
      rotation = mkDefault "right";
    } // mapAttrs (_: mkDefault) _4k;
  };
  layouts = {
    stacked = monitors: with monitors; {
      spectrum = { config, ... }: {
        imports = [ defaults.spectrum ];
        x = lg.x - config.viewport.width;
        y = dell.y - config.viewport.height;
      };
      dell = { config, ... }: {
        imports = [ defaults.dell ];
        x = 0;
        y = lg.y + lg.viewport.height - config.viewport.height;
      };
      lg = { config, ... }: {
        imports = [ defaults.lg ];
        x = dell.x + dell.viewport.width;
        y = max 0 ((spectrum.viewport.height + dell.viewport.height) - config.viewport.height);
      };
    };
    linear = monitors: with monitors; {
      spectrum = { config, ... }: {
        imports = [ defaults.spectrum ];
        x = 0;
        y = dell.y + dell.viewport.height - config.viewport.height;
      };
      dell = { config, ... }: {
        imports = [ defaults.dell ];
        x = spectrum.x + spectrum.viewport.width;
        y = lg.viewport.height - config.viewport.height;
      };
      lg = { config, ... }: {
        imports = [ defaults.lg ];
        x = dell.x + dell.viewport.width;
        y = 0;
      };
    };
    gaming = monitors: with monitors; {
      # linear but with spectrum in the middle
      spectrum = { config, ... }: {
        imports = [ defaults.spectrum ];
        x = dell.x + dell.viewport.width;
        y = dell.y + dell.viewport.height - config.viewport.height;
      };
      dell = { config, ... }: {
        imports = [ defaults.dell ];
        x = 0;
        y = lg.viewport.height - config.viewport.height;
      };
      lg = { config, ... }: {
        imports = [ defaults.lg ];
        x = spectrum.x + spectrum.viewport.width;
        y = 0;
      };
    };
    gaming-vertical = monitors: mkMerge [ (layouts.gaming monitors) {
      spectrum.rotation = "right";
    } ];
  };
in {
  monitors = layouts;
  default = layouts.stacked;
}
