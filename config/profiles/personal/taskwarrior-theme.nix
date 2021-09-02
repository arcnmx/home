{ pkgs, lib, base16 }: with lib; let
  colourNames = base16.map (b: "color${b.ansiStr}");
  # source: https://github.com/Cutuchiqueno/base16-monokai-themes
in with colourNames; pkgs.writeText "taskwarrior-base16-dark.theme" ''
  color=on
  fontunderline=off

  color.active=bold ${base0B}
  color.alternate=

  color.blocking=${base05}
  color.blocked=on ${base01}

  color.burndown.done=${base00} on ${base0D}
  color.burndown.pending=${base00} on ${base08}
  color.burndown.started=${base00} on ${base08}

  color.calendar.due=${base00} on ${base08}
  color.calendar.due.today=${base00} on ${base08}
  color.calendar.holiday=${base00} on ${base0A}
  color.calendar.overdue=${base00} on ${base0E}
  color.calendar.today=${base00} on ${base0D}
  color.calendar.weekend=on ${base00}
  color.calendar.weeknumber=${base0D}

  color.error=${base0C}
  color.debug=${base0C}
  color.due=${base0A}
  color.due.today=${base08}
  color.overdue=inverse
  color.scheduled=${base0D}
  color.footnote=${base0C}
  color.header=${base0D}

  color.history.add=${base00} on ${base08}
  color.history.delete=${base00} on ${base0A}
  color.history.done=${base00} on ${base0B}

  color.uda.priority.H=bold ${base05}
  color.uda.priority.M=${base05}
  color.uda.priority.L=${base03}
  color.uda.priority.=${base04}

  color.project.none=
  color.recurring=

  color.summary.background=on ${base00}
  color.summary.bar=${base00} on ${base0C}

  color.sync.added=
  color.sync.changed=
  color.sync.rejected=${base08}

  color.tag.none=
  color.tagged=${base0B}

  color.undo.after=${base0B}
  color.undo.before=${base08}
''
