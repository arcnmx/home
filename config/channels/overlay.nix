self: super: let
  inherit (self) lib;
in {
  # https://github.com/NixOS/nixpkgs/pull/223635
  parsec-bin = super.parsec-bin.override {
    ffmpeg = self.ffmpeg_4;
  };
}
