{ channelConfig ? {}, channelConfigPath ? null, pkgs ? null, channelPaths ? null } @ args: let
  mergeConfig = a: b: builtins.mapAttrs (name: value: value // (b.${name} or {})) a;
  channelPaths = args.channelPaths or {
    nixpkgs = ./nixpkgs;
    arc = ./arc;
    home-manager = ./home-manager;
    nur = ./nur;
    mozilla = ./mozilla;
  };
  channelNixPath = import ./path.nix { inherit channelPaths channelConfigPath; pkgs = channels.channels.nixpkgs; };
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
  inherit (channels) channels;
  inherit (channels.channels) pkgs nixpkgs home-manager arc nur;
}
