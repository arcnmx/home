self: super: {
  python3Packages = super.python3Packages // {
    openrazer-daemon = super.lib.warn "https://github.com/NixOS/nixpkgs/issues/194095"
      self.python3Packages.callPackage (self.path + "/pkgs/development/python-modules/openrazer/daemon.nix") { };
  };
}
