{ pkgs, channelPaths, channelConfigPath }: let
  canon = builtins.path {
    path = ./.;
    filter = (path: type: type != "directory" && baseNameOf path != "update");
  };
  channelPath = pkgs.substituteAll {
    name = "channels.nix";
    channels = canon;
    channelPaths = let
      paths = pkgs.lib.mapAttrsToList (name: v: "${name} = ${v};") channelPaths;
    in "{\n${pkgs.lib.concatStringsSep "\n" paths}\n}";
    src = builtins.toFile "channels.nix" ''
      args: let
        channelPaths = @channelPaths@;
        channels = @channels@;
      in import channels (args // { inherit channelPaths; })
    '';
  };
  channelOverride = { name, dir }: pkgs.stdenvNoCC.mkDerivation {
    channelConfigPath = assert channelConfigPath != null; channelConfigPath;
    channels = channelPath;
    paths = [dir];
    name = "channel-${name}";
    channelName = name;
    passAsFile = ["template"];
    template = ''
      { pkgs ? null, ... } @args: let
        channelConfigPath = import @channelConfigPath@;
        channelConfig = channelConfigPath // (if args != {} then {
          @channelName@ = channelConfigPath.@channelName@ or {} // args;
        } else {});
        channels = import @channels@ {
          ''${if args ? pkgs then "pkgs" else null} = pkgs;
          inherit channelConfig;
        };
      in channels.@channelName@
    '';
    buildCommand = ''
      mkdir -p $out
      for dir in $paths; do
        ln -s $dir/* $out/
      done
      rm $out/default.nix
      substituteAll $templatePath $out/default.nix
    '';
  };
  channelFiles = (builtins.mapAttrs (name: dir: channelOverride { inherit name dir; }) channelPaths) // {
    channels = channelPath;
  };
in channelFiles
