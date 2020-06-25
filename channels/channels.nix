{ pkgs ? null, channelPaths, channelOverlays, channelConfig ? {} }: let
  channelConfig' = {
    nixpkgs = { config = {}; overlays = channelOverlays; };
    home-manager = if pkgs != null then { inherit pkgs; } else { pkgs = channels.nixpkgs; };
    arc = if pkgs != null then { inherit pkgs; } else { pkgs = channels.nixpkgs; };
    nur = if pkgs != null then { inherit pkgs; nurpkgs = pkgs; } else { pkgs = channels.nixpkgs; nurpkgs = channels.nixpkgs; };
    rust = if pkgs != null then { inherit pkgs; } else { pkgs = channels.nixpkgs; };
  };
  channelConfig'' = builtins.mapAttrs (ch: config: config // (channelConfig.${ch} or {})) channelConfig';
  channels = (builtins.mapAttrs (ch: import channelPaths.${ch}) channelConfig'')
  // (if pkgs != null then { nixpkgs = pkgs; } else {}) // {
    pkgs = channels.nixpkgs;
  };
in {
  inherit channels;
  channelConfig = channelConfig'';
}
