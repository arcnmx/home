{ config, pkgs, lib, ... }: with lib; {
  options = {
    home.profiles.hw.x370gpc = mkEnableOption "MSI X370 Gaming Pro Carbon";
  };

  config = mkIf config.home.profiles.hw.x370gpc {
    home.profiles.hw.ryzen = true;

    boot.initrd.availableKernelModules = [
      "nvme" "sd_mod" "xhci_pci" "ahci" "usbhid"
    ];
    boot.kernelModules = [
      "nct6775"
    ];
    systemd.network = {
      networks.eno1 = {
        matchConfig.Name = "eno1";
        bridge = ["br"];
      };
      netdevs.br = {
        netdevConfig = {
          Name = "br";
          Kind = "bridge";
          MACAddress = "4c:cc:6a:f9:3d:ad";
        };
      };
    };

    environment.etc = {
      "sensors3.conf".text = ''
        chip "nct6795-isa-0a20"
            label in0 "Vcore"
            label in1 "+5V"
            compute in1 5*@, @/5
            label in2 "AVCC"
            set in2_min 3.3 * 0.90
            set in2_max 3.3 * 1.10
            label in3 "+3.3V"
            set in3_min 3.3 * 0.90
            set in3_max 3.3 * 1.10
            label in4 "+12V"
            compute in4 12*@, @/12
            label in5 "DIMM"
            compute in5 (8+18/19)*@, @/(8+18/19)
            # label in6 "wtf?" # can't find this in hwinfo64?
            label in7 "3VSB"
            set in7_min 3.3 * 0.90
            set in7_max 3.3 * 1.10
            label in8 "Vbat"
            set in8_min 3.3 * 0.90
            set in8_max 3.3 * 1.10
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
      '';
    };

    # fancontrol
    boot.kernel.sysctl = let
      nct = ".//.//.sys.devices.platform.nct6775/2592.hwmon.hwmon3";
    in {
      # motherboard
      "${nct}.temp1_max" = 40000;
      "${nct}.temp1_max_hyst" = 36000;

      # cpu (can't do this, max/hyst are shared with temp3)
      #${nct}.temp2_max=50000
      #${nct}.temp2_max_hyst=40000

      # System/Auxillary
      "${nct}.temp3_max" = 88000;
      "${nct}.temp3_max_hyst" = 60000;

      # rear exhaust
      #${nct}.pwm1_enable=1
      "${nct}.pwm1_temp_sel" = 2;
      "${nct}.pwm1_enable" = 5;
      "${nct}.pwm1_auto_point1_temp" = 35000;
      "${nct}.pwm1_auto_point1_pwm" = 88;
      "${nct}.pwm1_auto_point2_temp" = 38000;
      "${nct}.pwm1_auto_point2_pwm" = 104;
      "${nct}.pwm1_auto_point3_temp" = 47000;
      "${nct}.pwm1_auto_point3_pwm" = 144;
      "${nct}.pwm1_auto_point4_temp" = 49000;
      "${nct}.pwm1_auto_point4_pwm" = 224;
      "${nct}.pwm1_auto_point5_temp" = 52000;
      "${nct}.pwm1_auto_point5_pwm" = 255;
      "${nct}.pwm1_step_up_time" = 150;
      "${nct}.pwm1_step_down_time" = 150;

      # cpu fan
      #${nct}.pwm2_enable=1
      "${nct}.pwm2_temp_sel" = 2;
      "${nct}.pwm2_enable" = 5;
      "${nct}.pwm2_auto_point1_temp" = 34000;
      "${nct}.pwm2_auto_point1_pwm" = 0;
      "${nct}.pwm2_auto_point2_temp" = 34500;
      "${nct}.pwm2_auto_point2_pwm" = 128;
      "${nct}.pwm2_auto_point3_temp" = 47000;
      "${nct}.pwm2_auto_point3_pwm" = 160;
      "${nct}.pwm2_auto_point4_temp" = 49000;
      "${nct}.pwm2_auto_point4_pwm" = 224;
      "${nct}.pwm2_auto_point5_temp" = 52000;
      "${nct}.pwm2_auto_point5_pwm" = 255;
      "${nct}.pwm2_step_up_time" = 50;
      "${nct}.pwm2_step_down_time" = 50;

      # top exhaust
      #${nct}.pwm3_enable=1
      "${nct}.pwm3_temp_sel" = 2;
      "${nct}.pwm3_enable" = 5;
      "${nct}.pwm3_auto_point1_temp" = 36000;
      "${nct}.pwm3_auto_point1_pwm" = 0;
      "${nct}.pwm3_auto_point2_temp" = 39000;
      "${nct}.pwm3_auto_point2_pwm" = 136;
      "${nct}.pwm3_auto_point3_temp" = 48000;
      "${nct}.pwm3_auto_point3_pwm" = 144;
      "${nct}.pwm3_auto_point4_temp" = 50000;
      "${nct}.pwm3_auto_point4_pwm" = 176;
      "${nct}.pwm3_auto_point5_temp" = 53000;
      "${nct}.pwm3_auto_point5_pwm" = 255;
      "${nct}.pwm3_step_up_time" = 100;
      "${nct}.pwm3_step_down_time" = 100;

      # front 1 (bottom)
      "${nct}.pwm4_enable" = 1;
      "${nct}.pwm4" = 0; # fan is acting up :(
      #"${nct}.pwm4_temp_sel" = 2;
      #"${nct}.pwm4_enable" = 5;
      #"${nct}.pwm4_auto_point1_temp" = 35000;
      #"${nct}.pwm4_auto_point1_pwm" = 104;
      #"${nct}.pwm4_auto_point2_temp" = 38000;
      #"${nct}.pwm4_auto_point2_pwm" = 176;
      #"${nct}.pwm4_auto_point3_temp" = 47000;
      #"${nct}.pwm4_auto_point3_pwm" = 192;
      #"${nct}.pwm4_auto_point4_temp" = 49000;
      #"${nct}.pwm4_auto_point4_pwm" = 224;
      #"${nct}.pwm4_auto_point5_temp" = 52000;
      #"${nct}.pwm4_auto_point5_pwm" = 255;
      #"${nct}.pwm4_step_up_time" = 100;
      #"${nct}.pwm4_step_down_time" = 100;

      # top intake
      #${nct}.pwm5_enable=1
      "${nct}.pwm5_temp_sel" = 2;
      "${nct}.pwm5_enable" = 5;
      "${nct}.pwm5_auto_point1_temp" = 36000;
      "${nct}.pwm5_auto_point1_pwm" = 0; # 104, but ugh fan makes a little noise..?
      "${nct}.pwm5_auto_point2_temp" = 39000;
      "${nct}.pwm5_auto_point2_pwm" = 144;
      "${nct}.pwm5_auto_point3_temp" = 48000;
      "${nct}.pwm5_auto_point3_pwm" = 176;
      "${nct}.pwm5_auto_point4_temp" = 50000;
      "${nct}.pwm5_auto_point4_pwm" = 208;
      "${nct}.pwm5_auto_point5_temp" = 53000;
      "${nct}.pwm5_auto_point5_pwm" = 255;
      "${nct}.pwm5_step_up_time" = 100;
      "${nct}.pwm5_step_down_time" = 100;

      # front 2 (top)
      #${nct}.pwm6_enable=1
      "${nct}.pwm6_temp_sel" = 2;
      "${nct}.pwm6_enable" = 5;
      "${nct}.pwm6_auto_point1_temp" = 35000;
      "${nct}.pwm6_auto_point1_pwm" = 0; # 104, but ugh fan makes a little noise..?
      "${nct}.pwm6_auto_point2_temp" = 38000;
      "${nct}.pwm6_auto_point2_pwm" = 176;
      "${nct}.pwm6_auto_point3_temp" = 47000;
      "${nct}.pwm6_auto_point3_pwm" = 192;
      "${nct}.pwm6_auto_point4_temp" = 49000;
      "${nct}.pwm6_auto_point4_pwm" = 224;
      "${nct}.pwm6_auto_point5_temp" = 52000;
      "${nct}.pwm6_auto_point5_pwm" = 255;
      "${nct}.pwm6_step_up_time" = 100;
      "${nct}.pwm6_step_down_time" = 100;

      # Vcore
      "${nct}.in0_max" = 1500;
      # 5V (/5)
      "${nct}.in1_min" = 975;
      "${nct}.in1_max" = 1025;
      # AVCC
      "${nct}.in2_min" = 3300;
      "${nct}.in2_max" = 3500;
      # 3VCC
      "${nct}.in3_min" = 3270;
      "${nct}.in3_max" = 3400;
      # 12V (/12)
      "${nct}.in4_min" = 1000;
      "${nct}.in4_max" = 1050;
      # DIMM
      "${nct}.in5_min" = 130;
      "${nct}.in5_max" = 168;
      # 3VSB
      "${nct}.in7_min" = 3400;
      "${nct}.in7_max" = 3500;
      # VBAT
      "${nct}.in8_min" = 3350;
      "${nct}.in8_max" = 3400;
      # VTT
      "${nct}.in9_min" = 1800;
      "${nct}.in9_max" = 1900;
      # NB
      "${nct}.in12_min" = 900;
      "${nct}.in12_max" = 1200;
    };
  };
}
