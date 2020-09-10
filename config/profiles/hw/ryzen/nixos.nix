{ config, pkgs, lib, ... }: with lib; {
  options = {
    home.profiles.hw.ryzen = mkEnableOption "AMD Ryzen CPU";
  };

  config = mkIf config.home.profiles.hw.ryzen {
    boot = {
      kernel.sysctl = {
        "kernel.randomize_va_space" = 0; # related to https://bugzilla.kernel.org/show_bug.cgi?id=196683
      };
      kernelParams = ["amd_iommu=on"];
      kernelModules = [
        "msr" # for zenstates
        "kvm-amd"
      ];
      kernelPatches = optional (config.home.profiles.vfio && false) {
        # "Error: internal error: Unknown PCI header type ‘127’"
        # (though fixed in AGESA 1.0.0.4B, that update breaks RAM training so continue to use this patch until there's a better/stable version to update to)
        # As of 2019-12-03 there is a fixed version for my board and this is no longer necessary
        name = "pcie-reset-fix";
        patch = (pkgs.fetchurl {
          url = "https://clbin.com/VCiYJ";
          sha256 = "0xap49fn3287r8lb3xpayzmvmiy1hdv5ijalgh4052wn62mmh30k";
        });
      } ++ [ {
        # revert part of https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/commit/?id=c02f77d32d2c45cfb1b2bb99eabd8a78f5ecc7db
        name = "revert-amd-audio";
        patch = pkgs.writeText "revert-amd-audio.patch" ''
--- a/sound/pci/hda/hda_controller.c
+++ b/sound/pci/hda/hda_controller.c
@@ -613,13 +613,6 @@ static int azx_pcm_open(struct snd_pcm_substream *substream)
 				     20,
 				     178000000);

-	/* by some reason, the playback stream stalls on PulseAudio with
-	 * tsched=1 when a capture stream triggers.  Until we figure out the
-	 * real cause, disable tsched mode by telling the PCM info flag.
-	 */
-	if (chip->driver_caps & AZX_DCAPS_AMD_WORKAROUND)
-		runtime->hw.info |= SNDRV_PCM_INFO_BATCH;
-
 	if (chip->align_buffer_size)
 		/* constrain buffer sizes to be multiple of 128
 		   bytes. This is more efficient in terms of memory
        '';
      } ];
    };
    environment.etc = {
      "sensors3.conf".text = ''
        chip "k10temp-pci-00c3"
            label temp1 "Core"
      '';
    };
    environment.systemPackages = with pkgs; [
      lm_sensors
      #zenstates
    ];
  };
}
