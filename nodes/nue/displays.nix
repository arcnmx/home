{ lib }: with lib; let
  defaults = {
    internal = { config, ... }: {
      output = mkDefault "eDP";
      xserver.sectionName = mkDefault "Monitor[0]";
      primary = mkDefault true;
      width = 2880;
      height = 1800;
      dpi.target = 96 * 2;
      size = {
        diagonal = 13.3;
        width = 286;
        height = 179;
      };
    };
    spectrum = { config, ... }: {
      output = mkDefault "DisplayPort-2";
      source = mkDefault "DisplayPort-2";
      edid = mapAttrs (_: mkDefault) {
        manufacturer = "EVE";
        model = "ES07D03";
      };
      xserver.sectionName = mkDefault "Monitor[1]";
      refreshRate = mkDefault 144;
      width = 3840;
      height = 2160;
    };
  };
  layouts = {
    internal = monitors: with monitors; {
      internal = { config, ... }: {
        imports = [ defaults.internal ];
      };
    };
    stacked = monitors: with monitors; {
      internal = { config, ... }: {
        imports = [ defaults.internal ];
        x = spectrum.x + spectrum.viewport.width / 2 - config.viewport.width / 2;
        y = spectrum.y + spectrum.viewport.height;
      };
      spectrum = { config, ... }: {
        imports = [ defaults.spectrum ];
        x = 0;
        y = 0;
      };
    };
    side = monitors: with monitors; {
      internal = { config, ... }: {
        imports = [ defaults.internal ];
        x = 0;
        y = spectrum.viewport.height - config.viewport.height;
      };
      spectrum = { config, ... }: {
        imports = [ defaults.spectrum ];
        x = internal.x + internal.viewport.width;
        y = internal.y + internal.viewport.height;
      };
    };
  };
in {
  monitors = layouts;
  default = layouts.internal;
}
