{ runCommand
, lib
, makeWrapper
, coreutils, util-linux, lvm2
}: runCommand "map-disk" {
  src = ./map-disk.sh;
  nativeBuildInputs = [ makeWrapper ];
  path = lib.makeBinPath [ coreutils util-linux lvm2 ];
} ''
  install -Dm 0755 $src $out/bin/map-disk
  patchShebangs $out/bin/*
  wrapProgram $out/bin/map-disk --prefix PATH : "$path"
''
