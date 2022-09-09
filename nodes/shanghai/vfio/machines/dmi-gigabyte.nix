{ config, lib, ... }: with lib; let
  cfg = config.gigabyte;
  default = "Default string";
  unknown = "Unknown";
in {
  options.gigabyte = {
    mac = mkOption {
      type = with types; listOf str;
      default = [ "e0" "d5" "5e" "00" "00" "00" ];
    };
  };
  config.smbios = {
    smbios0.settings = {
      type = 0;
      uefi = true;
      vendor = "American Megatrends International, LLC.";
      date = "02/16/2022";
      version = "F36b";
      release = "5.17";
    };
    smbios1.settings = {
      type = 1;
      family = "X570 MB";
      manufacturer = "Gigabyte Technology Co., Ltd.";
      product = "X570 AORUS MASTER";
      version = "-CF";
      serial = default;
      sku = default;
      uuid = let
        submac = index: elemAt cfg.mac (index - 1);
      in "03${submac 2}02${submac 1}-04${submac 3}-05${submac 4}-${submac 5}06-${submac 6}0700080009";
    };
    smbios2.settings = {
      type = 2;
      product = "X570 AORUS MASTER";
      manufacturer = "Gigabyte Technology Co., Ltd.";
      version = default;
      serial = default;
      asset = default;
    };
    smbios3.settings = {
      type = 3;
      manufacturer = default;
      version = default;
      serial = default;
      asset = default;
      sku = default;
    };
    smbios4.settings = {
      type = 4;
      sock_pfx = "AM4";
      manufacturer = "Advanced Micro Devices, Inc.";
      part = "                                               ";
      serial = unknown;
      asset = unknown;
      version = unknown;
    };
    smbios17.settings = {
      type = 17;
      loc_pfx = "DIMM 0";
      bank = "P0 CHANNEL A";
      manufacturer = unknown;
      serial = "00000000";
      asset = unknown;
      part = "4400 C19 Series";
      speed = "3800";
    };
  };
}
