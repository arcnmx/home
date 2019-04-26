{ config, pkgs, lib, ... }:
{
  xsession.windowManager.i3 = let
    run = pkgs.writeShellScriptBin "run" ''
      ARGS=(${term} +sb
        -name run -title run -g 80x8
        -bg rgba:8888/3333/6666/cccc
        -fg rgb:e0/98/e0
        -e "$SHELL" -i
      )

      ARC_PROMPT_RUN=y exec "''${ARGS[@]}"
    '';
    alt = "Mod1";
    mod = "Mod4";
    left = "h";
    down = "j";
    up = "k";
    right = "l";
    term = "${pkgs.rxvt_unicode-with-plugins}/bin/urxvtc"; # urxvt
    #term = "${pkgs.xterm}/bin/xterm";
    i3-easyfocus = "${pkgs.i3-easyfocus}/bin/i3-easyfocus";
    lock = "${pkgs.i3lock}/bin/i3lock -e -u -c 111111";
    sleep = "${pkgs.coreutils}/bin/sleep";
    xset = "${pkgs.xorg.xset}/bin/xset";
    pactl = "${pkgs.pulseaudio}/bin/pactl";
    pkill = "${pkgs.procps}/bin/pkill";
    mosh = "${pkgs.mosh}/bin/mosh";
    ssh = "${pkgs.openssh}/bin/ssh";
    #vm = "${pkgs.arc.vm.exec}";
  in lib.mkIf config.home.profiles.gui {
    enable = true;
    i3gopher.enable = true;
    extraConfig = ''
      workspace_auto_back_and_forth yes
    '';
    config = {
      bars = [
        {
          fonts = ["monospace ${config.lib.gui.fontSizeStr 8}"];
          position = "top";
          colors = {
            statusline = "#ffffff";
            background = "#323232";
            inactiveWorkspace = {
              border = "#32323200";
              background = "#32323200";
              text = "#5c5c5c";
            };
          };
        }
      ];
      fonts = ["monospace ${config.lib.gui.fontSizeStr 6}"];
      modifier = mod;
      floating = {
        border = 1;
        modifier = mod;
        criteria = [
          { title = "^run$"; }
          { title = "^pinentry$"; }
        ];
      };
      focus = {
        forceWrapping = true;
      };
      startup = [
        { command = pkgs.arc.konawall.exec; always = true; notification = false; }
      ];
      window = {
        hideEdgeBorders = "smart";
        border = 1;
      };
      modes.resize = {
        ${left} = "resize shrink width 4 px or 4 ppt";
        ${down} = "resize grow height 4 px or 4 ppt";
        ${up} = "resize shrink height 4 px or 4 ppt";
        ${right} = "resize grow width 4 px or 4 ppt";

        Return = ''mode "default"'';
        Escape = ''mode "default"'';
        "${mod}+z" = ''mode "default"'';
      };
      keybindings = {
        "${mod}+z" = ''mode "resize"'';

        "${mod}+Return" = "exec ${term}";
        "${mod}+control+Return" = "exec ${term} -e ${ssh} shanghai";
        "${mod}+shift+Return" = "exec ${term} -e ${mosh} shanghai";

        "${mod}+shift+c" = "kill";
        "${mod}+r" = "exec ${run.exec}";

        "${mod}+shift+r" = "reload";

        "XF86AudioLowerVolume" = "exec --no-startup-id ${pactl} set-sink-volume @DEFAULT_SINK@ -5% && ${pkill} -USR1 i3status";
        "XF86AudioRaiseVolume" = "exec --no-startup-id ${pactl} set-sink-volume @DEFAULT_SINK@ +5% && ${pkill} -USR1 i3status";
        "XF86AudioMute" = "exec --no-startup-id ${pactl} set-sink-mute @DEFAULT_SINK@ toggle && ${pkill} -USR1 i3status";

        "--release ${mod}+p" = "exec --no-startup-id ${sleep} 0.2 && ${xset} dpms force off";

        # vm hotkeys
        #"--release KP_Divide" = "exec --no-startup-id ${vm} unseat";
        #"--release KP_Multiply" = "exec --no-startup-id ${vm} seat";

        # "--release ${mod}+bracketleft" = "exec ${pkgs.physlock}/bin/physlock -dms";
        "--release ${mod}+bracketleft" = "exec --no-startup-id ${pkgs.systemd}/bin/systemctl --user stop gpg-agent.service; exec --no-startup-id ${sleep} 0.2 && ${xset} dpms force off && ${lock}";

        "${mod}+shift+Escape" = "exit";

        "${mod}+grave" = "[urgent=latest] focus";
        "${mod}+n" = "[urgent=latest] focus";
        "${mod}+Tab" = "exec --no-startup-id ${pkgs.i3gopher.exec} --focus-last";
        "${mod}+control+f" = "exec --no-startup-id ${i3-easyfocus} -a || ${i3-easyfocus} -c";
        "${mod}+control+shift+f" = "exec --no-startup-id ${i3-easyfocus} -ar || ${i3-easyfocus} -cr";
        "${mod}+a" = "focus parent";
        "${mod}+q" = "focus child";
        #"${mod}+n" = "focus next";
        #"${mod}+m" = "focus prev";

        "${mod}+control+${left}" = "focus output left";
        "${mod}+control+${down}" = "focus output down";
        "${mod}+control+${up}" = "focus output up";
        "${mod}+control+${right}" = "focus output right";

        "${mod}+${left}" = "focus left";
        "${mod}+${down}" = "focus down";
        "${mod}+${up}" = "focus up";
        "${mod}+${right}" = "focus right";

        "${mod}+Left" = "focus left";
        "${mod}+Down" = "focus down";
        "${mod}+Up" = "focus up";
        "${mod}+Right" = "focus right";

        "${mod}+shift+control+${left}" = "move container to output left";
        "${mod}+shift+control+${down}" = "move container to output down";
        "${mod}+shift+control+${up}" = "move container to output up";
        "${mod}+shift+control+${right}" = "move container to output right";

        "${mod}+${alt}+shift+control+${left}" = "move workspace to output left";
        "${mod}+${alt}+shift+control+${down}" = "move workspace to output down";
        "${mod}+${alt}+shift+control+${up}" = "move workspace to output up";
        "${mod}+${alt}+shift+control+${right}" = "move workspace to output right";

        "${mod}+shift+a" = "move first";
        "${mod}+shift+n" = "move next";
        "${mod}+shift+m" = "move prev";

        "${mod}+shift+${left}" = "move left";
        "${mod}+shift+${down}" = "move down";
        "${mod}+shift+${up}" = "move up";
        "${mod}+shift+${right}" = "move right";

        "${mod}+shift+Left" = "move left";
        "${mod}+shift+Down" = "move down";
        "${mod}+shift+Up" = "move up";
        "${mod}+shift+Right" = "move right";

        "${mod}+1" = "workspace 1";
        "${mod}+2" = "workspace 2";
        "${mod}+3" = "workspace 3";
        "${mod}+4" = "workspace 4";
        "${mod}+5" = "workspace 5";
        "${mod}+6" = "workspace 6";
        "${mod}+7" = "workspace 7";
        "${mod}+8" = "workspace 8";
        "${mod}+9" = "workspace 9";
        "${mod}+0" = "workspace 10";

        "${mod}+shift+1" = "move container to workspace 1";
        "${mod}+shift+2" = "move container to workspace 2";
        "${mod}+shift+3" = "move container to workspace 3";
        "${mod}+shift+4" = "move container to workspace 4";
        "${mod}+shift+5" = "move container to workspace 5";
        "${mod}+shift+6" = "move container to workspace 6";
        "${mod}+shift+7" = "move container to workspace 7";
        "${mod}+shift+8" = "move container to workspace 8";
        "${mod}+shift+9" = "move container to workspace 9";
        "${mod}+shift+0" = "move container to workspace 10";

        "${mod}+control+1" = "exec --no-startup-id _i3workspaceoutput 1 current";
        "${mod}+control+2" = "exec --no-startup-id _i3workspaceoutput 2 current";
        "${mod}+control+3" = "exec --no-startup-id _i3workspaceoutput 3 current";
        "${mod}+control+4" = "exec --no-startup-id _i3workspaceoutput 4 current";
        "${mod}+control+5" = "exec --no-startup-id _i3workspaceoutput 5 current";
        "${mod}+control+6" = "exec --no-startup-id _i3workspaceoutput 6 current";
        "${mod}+control+7" = "exec --no-startup-id _i3workspaceoutput 7 current";
        "${mod}+control+8" = "exec --no-startup-id _i3workspaceoutput 8 current";
        "${mod}+control+9" = "exec --no-startup-id _i3workspaceoutput 9 current";
        "${mod}+control+0" = "exec --no-startup-id _i3workspaceoutput 0 current";

        "${mod}+b" = "splith";
        "${mod}+v" = "splitv";

        "${mod}+s" = "layout stacking";
        "${mod}+w" = "layout tabbed";
        "${mod}+e" = "layout toggle split";

        "${mod}+f" = "fullscreen";

        "${mod}+shift+space" = "floating toggle";

        "${mod}+space" = "focus mode_toggle";

        "${mod}+shift+minus" = "move scratchpad";
        "${mod}+minus" = "scratchpad show";
      };
    };
  };
}
