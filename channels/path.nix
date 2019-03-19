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
  channelOverride = { name, dir }: pkgs.symlinkJoin {
    channelConfigPath = assert channelConfigPath != null; channelConfigPath;
    channels = channelPath;
    paths = [dir];
    name = "channel-${name}";
    channelName = name;
    passAsFile = ["template"];
    template = ''
      { pkgs ? null, ... } @args: let
        channelConfigPath = @channelConfigPath@;
        channelConfig = if args != {} then { @channelName@ = args; } else {};
        channels = import @channels@ { inherit pkgs channelConfig; };
      in channels.@channelName@
    '';
    postBuild = ''
      rm $out/default.nix
      substituteAll $templatePath $out/default.nix
    '';
  };
  channelFiles = (builtins.mapAttrs (name: dir: channelOverride { inherit name dir; }) channelPaths) // {
    channels = channelPath;
  };
in channelFiles
