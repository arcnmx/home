{ lib }: with lib; let
  defaults = {
    _4k = mapAttrs (_: mkDefault) {
      width = 3840;
      height = 2160;
    };
    common = { config, ... }: {
      nvidia.options.AllowGSYNCCompatible = mkIf (hasPrefix "DP-" config.output) (mkOptionDefault "On");
    };
    spectrum-4k144 = { config, ... }: {
      imports = [ defaults.common defaults._4k ];
      nvidia.options.AllowGSYNCCompatible = mkIf (hasPrefix "HDMI-" config.output && nixosConfig.hardware.vfio.rtx3080.gpu.primary) (mkDefault "On");
      edid = mapAttrs (_: mkDefault) {
        manufacturer = "EVE";
        model = "ES07D03";
      };
      xserver.sectionName = mkDefault "Monitor[0]";
      refreshRate = mkDefault 144;
      primary = mkDefault true;
    };
    spectrum-typec = { config, ... }: {
      imports = [ defaults.spectrum-4k144 ];
      output = mkDefault "DP-2";
      source = mkDefault "DisplayPort-2"; # broken USB Type-C port
    };
    spectrum-hdmi = { config, ... }: {
      imports = [ defaults.spectrum-4k144 ];
      output = mkDefault "DP-0";
      source = mkDefault "HDMI-2";
      nvidia = {
        options.AllowGSYNCCompatible = null;
        flatPanelOptions = {
          Dithering = "Disabled";
        };
      };
    };
    dell = { config, ... }: {
      imports = [ defaults.common defaults._4k ];
      output = mkDefault "HDMI-0";
      source = mkDefault "HDMI-1";
      edid = mapAttrs (_: mkDefault) {
        manufacturer = "DEL";
        model = "DELL S2721QS";
      };
      xserver.sectionName = mkDefault "Monitor[1]";
    };
    lg = { config, ... }: {
      imports = [ defaults.common defaults._4k ];
      enable = false;
      output = mkDefault "DP-2";
      edid = mapAttrs (_: mkDefault) {
        manufacturer = "GSM";
        model = "LG Ultra HD";
      };
      xserver.sectionName = mkDefault "Monitor[2]";
      rotation = mkDefault "right";
    };
  };
  layouts = {
    stacked = monitors: with monitors; {
      dell = { config, ... }: {
        imports = [ defaults.dell ];
        x = lg.x - config.viewport.width;
        y = spectrum.y - config.viewport.height;
      };
      spectrum = { config, ... }: {
        imports = [ defaults.spectrum-typec ];
        x = 0;
        y = lg.y + lg.viewport.height - config.viewport.height;
      };
      lg = { config, ... }: {
        imports = [ defaults.lg ];
        x = spectrum.x + spectrum.viewport.width;
        y = max 0 ((spectrum.viewport.height + dell.viewport.height) - config.viewport.height);
      };
    };
    linear = monitors: with monitors; {
      spectrum = { config, ... }: {
        imports = [ defaults.spectrum-typec ];
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
        imports = [ defaults.spectrum-typec ];
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
  default = layouts.gaming;
}
