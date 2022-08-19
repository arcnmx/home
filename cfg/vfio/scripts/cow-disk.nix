{ runCommand
, lib
, makeWrapper
, coreutils, util-linux, lvm2
}: runCommand "cow-disk" {
  src = ./cow-disk.sh;
  nativeBuildInputs = [ makeWrapper ];
  path = lib.makeBinPath [ coreutils util-linux lvm2 ];
} ''
  install -Dm 0755 $src $out/bin/cow-disk
  patchShebangs $out/bin/*
  wrapProgram $out/bin/cow-disk --prefix PATH : "$path"
''
