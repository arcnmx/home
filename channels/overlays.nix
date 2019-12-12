{ channelPaths, channels }: let
  channelOverlayPaths = with channelPaths; [ rust home-manager arc ];
  channelOverlay = self: super: {
    inherit channels;
    inherit (channels) nur;
    import = self.lib.nixPathImport channelPaths; # resolve all imports without relying on the NIX_PATH environment
  };
in (map (ch: import "${toString ch}/overlay.nix") channelOverlayPaths) ++ [
  channelOverlay
]
