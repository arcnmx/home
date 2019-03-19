{ config, pkgs, lib, ... }: with lib; {
  options = {
    home.profiles.host.shanghai = mkEnableOption "hostname: shanghai";
  };

  config = mkIf config.home.profiles.host.shanghai {
    home.profiles.trusted = true;

    networking.hostId = "a1184652";

    services.mosh.portRange = "32600:32700";
    hardware.pulseaudio.extraConfig = lib.mkAfter ''
      #load-module module-mmkbd-evdev

      load-module module-virtual-surround-sink sink_name=vsurround sink_master=alsa_output.usb-C-Media_Electronics_Inc._USB_Audio_Device-00.analog-stereo hrir=/etc/pulse/hrir_kemar/hrir-kemar.wav

      set-default-sink alsa_output.pci-0000_20_00.3.analog-stereo
      #set-default-source alsa_input.pci-0000_20_00.3.analog-stereo # broken alsa driver

      #set-default-sink alsa_output.usb-C-Media_Electronics_Inc._USB_Audio_Device-00.analog-stereo
      set-default-source alsa_input.usb-C-Media_Electronics_Inc._USB_Audio_Device-00.analog-mono
    '';
  };
}
