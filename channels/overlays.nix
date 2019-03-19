{ channelPaths, channels }: let
  channelOverlayPaths = {
    inherit (channelPaths) home-manager arc;
  };
  channelOverlay = self: super: {
    inherit channels;
    inherit (channels) nur;
  };
in (map (ch: import "${toString ch}/overlay.nix") (builtins.attrValues channelOverlayPaths)) ++ [
  channelOverlay
  (import "${toString channelPaths.arc}/overlays/profiles.nix")
  (import "${toString channelPaths.mozilla}/rust-overlay.nix")
]
