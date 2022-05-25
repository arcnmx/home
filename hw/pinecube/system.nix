{ systems }: systems.examples.armv7l-hf-multiplatform // {
  gcc = {
    arch = "armv7-a";
    tune = "cortex-a7";
    #cpu = "cortex-a7+mp";
    #fpu = "vfpv3-d16";
    fpu = "neon-vfpv4";
  };
  name = "pinecube";
  linux-kernel = systems.platforms.armv7l-hf-multiplatform.linux-kernel // {
    name = "pinecube";
    # sunxi_defconfig is missing wireless support
    # TODO: Are all of these options needed here?
    baseConfig = "sunxi_defconfig";
    extraConfig = ''
      CFG80211 m
      WIRELESS y
      WLAN y
      RFKILL y
      RFKILL_INPUT y
      RFKILL_GPIO y
      KERNEL_LZMA y
    '';
  };
}
