{ lib }: with lib; let
  targetModule = { config, name, ... }: {
    options = {
      enable = mkEnableOption "target" // {
        default = true;
      };
      name = mkOption {
        type = types.str;
        default = name;
      };
      nodeNames = mkOption {
        type = types.listOf types.str;
        default = [ ];
      };
    };
  };
  targetType = types.submoduleWith {
    modules = [ targetModule ];
  };
  options.targets = lib.mkOption {
    type = types.attrsOf targetType;
    default = { };
  };
in {
  __functor = self: { ... }: {
    inherit options;
  };
}
