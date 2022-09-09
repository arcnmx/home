{ runCommand
, lib
, makeWrapper
, coreutils, systemd
}: runCommand "alloc-hugepages" {
  src = ./alloc-hugepages.sh;
  nativeBuildInputs = [ makeWrapper ];
  path = lib.makeBinPath [ coreutils systemd ];
} ''
  install -Dm 0755 $src $out/bin/alloc-hugepages
  patchShebangs $out/bin/*
  wrapProgram $out/bin/alloc-hugepages --prefix PATH : "$path"
''
