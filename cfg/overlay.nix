self: super: let
  inherit (self) lib;
in {
  zsh = super.zsh.overrideAttrs (old: {
    patches = old.patches or [ ] ++ [
      ./shell/zsh-globquote.patch
    ];
  });
  zshVanilla = super.zsh;

  linuxKernel = let
    inherit (super.linuxKernel.kernels) linux_testing;
    kernelData = {
      "6.1-rc6".hash = "sha256-yW1r4F5h8iGK5F53QCW50/pJTRos1kMLnfJmlpsssew=";
      #"6.1-rc7".hash = "sha256-5S9SY7BhSIux8aWREkZE93bwiG3sDSIB8bxMG9eNFJc="; # 6.1-rc7 (doesn't build :<)
      "6.2-rc6".hash = "sha256-rEpJYw5O6OHSwNY8LxlCsw0p9+u9BUjTQ8FsB6+fLbc=";
    };
    kernelVersions = lib.sort lib.versionAtLeast (lib.attrNames kernelData);
    isTesting = lib.hasInfix "-rc";
    kernelArgs = lib.mapAttrs genArgs kernelData;
    genArgs = version: { hash, args ? { }, ... }: {
      inherit version;
      extraMeta.branch = lib.versions.majorMinor version;
      modDirVersion = lib.versions.pad 3 version;
      src = self.fetchurl {
        inherit hash;
        url = if isTesting version
          then "https://git.kernel.org/torvalds/t/linux-${version}.tar.gz"
          else "mirror://kernel/linux/kernel/v${lib.versions.major version}.x/linux-${version}.tar.xz";
      };
    } // args;
    testing = lib.findFirst isTesting null kernelVersions;
    release = lib.findFirst (v: ! isTesting v) null kernelVersions;
  in super.linuxKernel // {
    kernels = super.linuxKernel.kernels // {
      linux_testing = if testing != null && lib.versionOlder linux_testing.version testing
        then linux_testing.override {
          argsOverride = kernelArgs.${testing};
        } else linux_testing;
    };
  };
}
