{ channelConfig ? {}, channelConfigPath ? null, pkgs ? null, channelPaths ? null } @ args: let
  mergeConfig = a: b: builtins.mapAttrs (name: value: value // (b.${name} or {})) a;
  channelSource = path: builtins.path {
    inherit path;
    name = "source";
    filter = p: t: baseNameOf p != ".git";
  };
  channelPaths = args.channelPaths or {
    nixpkgs = ./nixpkgs;
    arc = ./arc;
    home-manager = ./home-manager;
    nur = ./nur;
    mozilla = ./mozilla;
    rust = ./rust;
  };
  channelNixPath = import ./path.nix {
    inherit channelConfigPath;
    pkgs = channels.channels.nixpkgs;
    channelPaths = builtins.mapAttrs (_: channelSource) channelPaths;
  };
  channelOverlays = import ./overlays.nix { inherit channelPaths; inherit (channels) channels; };
  channels = import ./channels.nix {
    inherit channelPaths channelConfig channelOverlays;
    ${if args ? pkgs then "pkgs" else null} = args.pkgs;
  };
in {
  paths = channelPaths;
  overlays = channelOverlays;
  imports = channelNixPath;
  nixPath = map (ch: "${ch}=${channelNixPath.${ch}}") (builtins.attrNames channelNixPath);
  config = channels.channelConfig;
  inherit (channels.channels.pkgs) import;
  inherit (channels) channels;
  inherit (channels.channels) pkgs nixpkgs home-manager arc nur rust;
}
