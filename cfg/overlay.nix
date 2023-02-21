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
      "6.2-rc6".hash = "sha256-rEpJYw5O6OHSwNY8LxlCsw0p9+u9BUjTQ8FsB6+fLbc=";
    };
    kernelVersions = lib.sort kernelVersionAtLeast (lib.attrNames kernelData);
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
    testingKernels = lib.mapAttrs' (version: argsOverride: lib.nameValuePair (linuxRcKeyFor version) (
      linux_testing.override {
        inherit argsOverride;
      }
    )) kernelArgs;
    linuxRcKeyFor = version: "linux_" + lib.replaceStrings [ "." "-" ] [ "_" "_" ] version;
    linuxKeyFor = version: "linux_" + lib.replaceStrings [ "." ] [ "_" ] (
      lib.versions.majorMinor version
    ) + lib.optionalString (isTesting version) "_testing";
    kernelVersionAtLeast = l: r: let
      lver = lib.versions.majorMinor l;
      rver = lib.versions.majorMinor r;
    in if lver != rver
      then lib.versionAtLeast lver rver
      else isTesting r && (lib.versionAtLeast l r);
  in super.linuxKernel // {
    kernels = super.linuxKernel.kernels // {
      linux_testing = if testing != null && kernelVersionAtLeast linux_testing.version testing
        then linux_testing.override {
          argsOverride = kernelArgs.${testing};
        } else linux_testing;
    } // testingKernels;
    testingKernels = super.linuxKernel.testingKernels or {
      ${if isTesting self.linuxKernel.kernels.linux_testing.version then linuxKeyFor self.linuxKernel.kernels.linux_testing.version else null} = self.linuxKernel.kernels.linux_testing;
      ${if isTesting linux_testing.version then linuxRcKeyFor linux_testing.version else null} = super.linuxKernel.kernels.linux_testing;
    } // testingKernels;
    testingPackages = super.linuxKernel.testingPackages or {
      ${if isTesting self.linuxKernel.kernels.linux_testing.version then linuxKeyFor self.linuxKernel.kernels.linux_testing.version else null} = self.linuxKernel.packages.linux_testing;
      ${if isTesting linux_testing.version then linuxRcKeyFor linux_testing.version else null} = super.linuxKernel.packages.linux_testing;
    } // lib.mapAttrs (_: self.linuxKernel.packagesFor) testingKernels;
    packages = super.linuxKernel.packages //
      lib.mapAttrs (name: _: self.linuxKernel.testingPackages.${name}) testingKernels;
  };
}
