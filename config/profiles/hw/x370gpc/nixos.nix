{ config, pkgs, lib, ... }: with lib; {
  options = {
    home.profiles.hw.x370gpc = mkEnableOption "MSI X370 Gaming Pro Carbon";
  };

  config = mkIf config.home.profiles.hw.x370gpc {
    home.profiles.hw.ryzen = true;

    boot.kernelModules = [
      "nct6775"
      "nvme" "sd_mod" "xhci_pci" "ahci" "usbhid"
    ];
    systemd.network.links.eth = {
      matchConfig = {
        MACAddress = "4c:cc:6a:f9:3d:ad";
        Path = "pci-0000:17:00.0";
      };
      linkConfig = {
        Name = "eth";
      };
    };
    systemd.network.netdevs.br = {
      netdevConfig = {
        Name = "br";
        Kind = "bridge";
        MACAddress = "4c:cc:6a:f9:3d:ad";
      };
    };

    environment.etc = {
      "sensors.d/msi-x370-gaming-pro-carbon".text = ''
        chip "nct6795-isa-0a20"
            label in0 "Vcore"
            label in1 "+5V"
            compute in1 5*@, @/5
            label in2 "AVCC"
            label in3 "3VCC"
            label in4 "+12V"
            compute in4 12*@, @/12
            label in5 "DIMM"
            compute in5 (8+18/19)*@, @/(8+18/19)
            # label in6 "wtf?" # can't find this in hwinfo64?
            label in7 "3VSB"
            label in8 "VBAT"
            label in9 "VTT"
            ignore in10 # always zero
            # label in11 "VIN4" # on hwinfo64
            label in12 "SoC" # "CPU NB"  on hwinfo64
            # label in13 "VIN6" # on hwinfo64
            # label in13 "VIN7" # on hwinfo64
            label fan1 "Rear Fan" # "Pump Fan"
            label fan2 "CPU Fan"
            label fan3 "Top Exhaust" # "Case Fan 1"
            label fan4 "Front Fan" # "Case Fan 2"
            label fan5 "Top Intake" # "Case Fan 3"
            label fan6 "Front Fan" # "Case Fan 4"
            label temp7 "Core"
            label temp1 "Motherboard"
            label temp2 "CPU"
            label temp3 "System" # Auxillary

            ignore temp4
            ignore temp6
            ignore temp8
            ignore temp9
            ignore temp10
            ignore intrusion0
            ignore intrusion1
            ignore beep_enable
            # 1700x: compute temp7 @-20,@+20
      '';
    };

    # fancontrol
    boot.kernel.sysctl = {
      # motherboard
      ".//.//.sys.devices.platform.nct6775/2592.hwmon.hwmon0.temp1_max" = 40000;
      ".//.//.sys.devices.platform.nct6775/2592.hwmon.hwmon0.temp1_max_hyst" = 36000;

      # cpu (can't do this, max/hyst are shared with temp3)
      #.//.//.sys.devices.platform.nct6775/2592.hwmon.hwmon0.temp2_max=50000
      #.//.//.sys.devices.platform.nct6775/2592.hwmon.hwmon0.temp2_max_hyst=40000

      # System/Auxillary
      ".//.//.sys.devices.platform.nct6775/2592.hwmon.hwmon0.temp3_max" = 75000;
      ".//.//.sys.devices.platform.nct6775/2592.hwmon.hwmon0.temp3_max_hyst" = 54000;

      # rear exhaust
      #.//.//.sys.devices.platform.nct6775/2592.hwmon.hwmon0.pwm1_mode=1
      ".//.//.sys.devices.platform.nct6775/2592.hwmon.hwmon0.pwm1_temp_sel" = 2;
      ".//.//.sys.devices.platform.nct6775/2592.hwmon.hwmon0.pwm1_enable" = 5;
      ".//.//.sys.devices.platform.nct6775/2592.hwmon.hwmon0.pwm1_auto_point1_temp" = 35000;
      ".//.//.sys.devices.platform.nct6775/2592.hwmon.hwmon0.pwm1_auto_point1_pwm" = 88;
      ".//.//.sys.devices.platform.nct6775/2592.hwmon.hwmon0.pwm1_auto_point2_temp" = 38000;
      ".//.//.sys.devices.platform.nct6775/2592.hwmon.hwmon0.pwm1_auto_point2_pwm" = 104;
      ".//.//.sys.devices.platform.nct6775/2592.hwmon.hwmon0.pwm1_auto_point3_temp" = 47000;
      ".//.//.sys.devices.platform.nct6775/2592.hwmon.hwmon0.pwm1_auto_point3_pwm" = 144;
      ".//.//.sys.devices.platform.nct6775/2592.hwmon.hwmon0.pwm1_auto_point4_temp" = 49000;
      ".//.//.sys.devices.platform.nct6775/2592.hwmon.hwmon0.pwm1_auto_point4_pwm" = 224;
      ".//.//.sys.devices.platform.nct6775/2592.hwmon.hwmon0.pwm1_auto_point5_temp" = 52000;
      ".//.//.sys.devices.platform.nct6775/2592.hwmon.hwmon0.pwm1_auto_point5_pwm" = 255;
      ".//.//.sys.devices.platform.nct6775/2592.hwmon.hwmon0.pwm1_step_up_time" = 150;
      ".//.//.sys.devices.platform.nct6775/2592.hwmon.hwmon0.pwm1_step_down_time" = 150;

      # cpu fan
      #.//.//.sys.devices.platform.nct6775/2592.hwmon.hwmon0.pwm2_mode=1
      ".//.//.sys.devices.platform.nct6775/2592.hwmon.hwmon0.pwm2_temp_sel" = 2;
      ".//.//.sys.devices.platform.nct6775/2592.hwmon.hwmon0.pwm2_enable" = 5;
      ".//.//.sys.devices.platform.nct6775/2592.hwmon.hwmon0.pwm2_auto_point1_temp" = 34000;
      ".//.//.sys.devices.platform.nct6775/2592.hwmon.hwmon0.pwm2_auto_point1_pwm" = 0;
      ".//.//.sys.devices.platform.nct6775/2592.hwmon.hwmon0.pwm2_auto_point2_temp" = 34500;
      ".//.//.sys.devices.platform.nct6775/2592.hwmon.hwmon0.pwm2_auto_point2_pwm" = 128;
      ".//.//.sys.devices.platform.nct6775/2592.hwmon.hwmon0.pwm2_auto_point3_temp" = 47000;
      ".//.//.sys.devices.platform.nct6775/2592.hwmon.hwmon0.pwm2_auto_point3_pwm" = 160;
      ".//.//.sys.devices.platform.nct6775/2592.hwmon.hwmon0.pwm2_auto_point4_temp" = 49000;
      ".//.//.sys.devices.platform.nct6775/2592.hwmon.hwmon0.pwm2_auto_point4_pwm" = 224;
      ".//.//.sys.devices.platform.nct6775/2592.hwmon.hwmon0.pwm2_auto_point5_temp" = 52000;
      ".//.//.sys.devices.platform.nct6775/2592.hwmon.hwmon0.pwm2_auto_point5_pwm" = 255;
      ".//.//.sys.devices.platform.nct6775/2592.hwmon.hwmon0.pwm2_step_up_time" = 50;
      ".//.//.sys.devices.platform.nct6775/2592.hwmon.hwmon0.pwm2_step_down_time" = 50;

      # top exhaust
      #.//.//.sys.devices.platform.nct6775/2592.hwmon.hwmon0.pwm3_mode=1
      ".//.//.sys.devices.platform.nct6775/2592.hwmon.hwmon0.pwm3_temp_sel" = 2;
      ".//.//.sys.devices.platform.nct6775/2592.hwmon.hwmon0.pwm3_enable" = 5;
      ".//.//.sys.devices.platform.nct6775/2592.hwmon.hwmon0.pwm3_auto_point1_temp" = 36000;
      ".//.//.sys.devices.platform.nct6775/2592.hwmon.hwmon0.pwm3_auto_point1_pwm" = 0;
      ".//.//.sys.devices.platform.nct6775/2592.hwmon.hwmon0.pwm3_auto_point2_temp" = 39000;
      ".//.//.sys.devices.platform.nct6775/2592.hwmon.hwmon0.pwm3_auto_point2_pwm" = 136;
      ".//.//.sys.devices.platform.nct6775/2592.hwmon.hwmon0.pwm3_auto_point3_temp" = 48000;
      ".//.//.sys.devices.platform.nct6775/2592.hwmon.hwmon0.pwm3_auto_point3_pwm" = 144;
      ".//.//.sys.devices.platform.nct6775/2592.hwmon.hwmon0.pwm3_auto_point4_temp" = 50000;
      ".//.//.sys.devices.platform.nct6775/2592.hwmon.hwmon0.pwm3_auto_point4_pwm" = 176;
      ".//.//.sys.devices.platform.nct6775/2592.hwmon.hwmon0.pwm3_auto_point5_temp" = 53000;
      ".//.//.sys.devices.platform.nct6775/2592.hwmon.hwmon0.pwm3_auto_point5_pwm" = 255;
      ".//.//.sys.devices.platform.nct6775/2592.hwmon.hwmon0.pwm3_step_up_time" = 100;
      ".//.//.sys.devices.platform.nct6775/2592.hwmon.hwmon0.pwm3_step_down_time" = 100;

      # front 1
      #.//.//.sys.devices.platform.nct6775/2592.hwmon.hwmon0.pwm4_mode=1
      ".//.//.sys.devices.platform.nct6775/2592.hwmon.hwmon0.pwm4_temp_sel" = 2;
      ".//.//.sys.devices.platform.nct6775/2592.hwmon.hwmon0.pwm4_enable" = 5;
      ".//.//.sys.devices.platform.nct6775/2592.hwmon.hwmon0.pwm4_auto_point1_temp" = 35000;
      ".//.//.sys.devices.platform.nct6775/2592.hwmon.hwmon0.pwm4_auto_point1_pwm" = 104;
      ".//.//.sys.devices.platform.nct6775/2592.hwmon.hwmon0.pwm4_auto_point2_temp" = 38000;
      ".//.//.sys.devices.platform.nct6775/2592.hwmon.hwmon0.pwm4_auto_point2_pwm" = 176;
      ".//.//.sys.devices.platform.nct6775/2592.hwmon.hwmon0.pwm4_auto_point3_temp" = 47000;
      ".//.//.sys.devices.platform.nct6775/2592.hwmon.hwmon0.pwm4_auto_point3_pwm" = 192;
      ".//.//.sys.devices.platform.nct6775/2592.hwmon.hwmon0.pwm4_auto_point4_temp" = 49000;
      ".//.//.sys.devices.platform.nct6775/2592.hwmon.hwmon0.pwm4_auto_point4_pwm" = 224;
      ".//.//.sys.devices.platform.nct6775/2592.hwmon.hwmon0.pwm4_auto_point5_temp" = 52000;
      ".//.//.sys.devices.platform.nct6775/2592.hwmon.hwmon0.pwm4_auto_point5_pwm" = 255;
      ".//.//.sys.devices.platform.nct6775/2592.hwmon.hwmon0.pwm4_step_up_time" = 100;
      ".//.//.sys.devices.platform.nct6775/2592.hwmon.hwmon0.pwm4_step_down_time" = 100;

      # top intake
      #.//.//.sys.devices.platform.nct6775/2592.hwmon.hwmon0.pwm5_mode=1
      ".//.//.sys.devices.platform.nct6775/2592.hwmon.hwmon0.pwm5_temp_sel" = 2;
      ".//.//.sys.devices.platform.nct6775/2592.hwmon.hwmon0.pwm5_enable" = 5;
      ".//.//.sys.devices.platform.nct6775/2592.hwmon.hwmon0.pwm5_auto_point1_temp" = 36000;
      ".//.//.sys.devices.platform.nct6775/2592.hwmon.hwmon0.pwm5_auto_point1_pwm" = 104;
      ".//.//.sys.devices.platform.nct6775/2592.hwmon.hwmon0.pwm5_auto_point2_temp" = 39000;
      ".//.//.sys.devices.platform.nct6775/2592.hwmon.hwmon0.pwm5_auto_point2_pwm" = 144;
      ".//.//.sys.devices.platform.nct6775/2592.hwmon.hwmon0.pwm5_auto_point3_temp" = 48000;
      ".//.//.sys.devices.platform.nct6775/2592.hwmon.hwmon0.pwm5_auto_point3_pwm" = 176;
      ".//.//.sys.devices.platform.nct6775/2592.hwmon.hwmon0.pwm5_auto_point4_temp" = 50000;
      ".//.//.sys.devices.platform.nct6775/2592.hwmon.hwmon0.pwm5_auto_point4_pwm" = 208;
      ".//.//.sys.devices.platform.nct6775/2592.hwmon.hwmon0.pwm5_auto_point5_temp" = 53000;
      ".//.//.sys.devices.platform.nct6775/2592.hwmon.hwmon0.pwm5_auto_point5_pwm" = 255;
      ".//.//.sys.devices.platform.nct6775/2592.hwmon.hwmon0.pwm5_step_up_time" = 100;
      ".//.//.sys.devices.platform.nct6775/2592.hwmon.hwmon0.pwm5_step_down_time" = 100;

      # front 2
      #.//.//.sys.devices.platform.nct6775/2592.hwmon.hwmon0.pwm6_mode=1
      ".//.//.sys.devices.platform.nct6775/2592.hwmon.hwmon0.pwm6_temp_sel" = 2;
      ".//.//.sys.devices.platform.nct6775/2592.hwmon.hwmon0.pwm6_enable" = 5;
      ".//.//.sys.devices.platform.nct6775/2592.hwmon.hwmon0.pwm6_auto_point1_temp" = 35000;
      ".//.//.sys.devices.platform.nct6775/2592.hwmon.hwmon0.pwm6_auto_point1_pwm" = 104;
      ".//.//.sys.devices.platform.nct6775/2592.hwmon.hwmon0.pwm6_auto_point2_temp" = 38000;
      ".//.//.sys.devices.platform.nct6775/2592.hwmon.hwmon0.pwm6_auto_point2_pwm" = 176;
      ".//.//.sys.devices.platform.nct6775/2592.hwmon.hwmon0.pwm6_auto_point3_temp" = 47000;
      ".//.//.sys.devices.platform.nct6775/2592.hwmon.hwmon0.pwm6_auto_point3_pwm" = 192;
      ".//.//.sys.devices.platform.nct6775/2592.hwmon.hwmon0.pwm6_auto_point4_temp" = 49000;
      ".//.//.sys.devices.platform.nct6775/2592.hwmon.hwmon0.pwm6_auto_point4_pwm" = 224;
      ".//.//.sys.devices.platform.nct6775/2592.hwmon.hwmon0.pwm6_auto_point5_temp" = 52000;
      ".//.//.sys.devices.platform.nct6775/2592.hwmon.hwmon0.pwm6_auto_point5_pwm" = 255;
      ".//.//.sys.devices.platform.nct6775/2592.hwmon.hwmon0.pwm6_step_up_time" = 100;
      ".//.//.sys.devices.platform.nct6775/2592.hwmon.hwmon0.pwm6_step_down_time" = 100;

      # Vcore
      ".//.//.sys.devices.platform.nct6775/2592.hwmon.hwmon0.in0_max" = 1500;
      # 5V (/5)
      ".//.//.sys.devices.platform.nct6775/2592.hwmon.hwmon0.in1_min" = 975;
      ".//.//.sys.devices.platform.nct6775/2592.hwmon.hwmon0.in1_max" = 1025;
      # AVCC
      ".//.//.sys.devices.platform.nct6775/2592.hwmon.hwmon0.in2_min" = 3300;
      ".//.//.sys.devices.platform.nct6775/2592.hwmon.hwmon0.in2_max" = 3500;
      # 3VCC
      ".//.//.sys.devices.platform.nct6775/2592.hwmon.hwmon0.in3_min" = 3270;
      ".//.//.sys.devices.platform.nct6775/2592.hwmon.hwmon0.in3_max" = 3400;
      # 12V (/12)
      ".//.//.sys.devices.platform.nct6775/2592.hwmon.hwmon0.in4_min" = 1000;
      ".//.//.sys.devices.platform.nct6775/2592.hwmon.hwmon0.in4_max" = 1050;
      # DIMM
      ".//.//.sys.devices.platform.nct6775/2592.hwmon.hwmon0.in5_min" = 130;
      ".//.//.sys.devices.platform.nct6775/2592.hwmon.hwmon0.in5_max" = 168;
      # 3VSB
      ".//.//.sys.devices.platform.nct6775/2592.hwmon.hwmon0.in7_min" = 3400;
      ".//.//.sys.devices.platform.nct6775/2592.hwmon.hwmon0.in7_max" = 3500;
      # VBAT
      ".//.//.sys.devices.platform.nct6775/2592.hwmon.hwmon0.in8_min" = 3350;
      ".//.//.sys.devices.platform.nct6775/2592.hwmon.hwmon0.in8_max" = 3400;
      # VTT
      ".//.//.sys.devices.platform.nct6775/2592.hwmon.hwmon0.in9_min" = 1800;
      ".//.//.sys.devices.platform.nct6775/2592.hwmon.hwmon0.in9_max" = 1900;
      # NB
      ".//.//.sys.devices.platform.nct6775/2592.hwmon.hwmon0.in12_min" = 900;
      ".//.//.sys.devices.platform.nct6775/2592.hwmon.hwmon0.in12_max" = 1200;
    };
  };
}
