{ runCommand
, lib
, makeWrapper
, coreutils, pciutils, kmod
}: runCommand "reserve-pci" {
  src = ./reserve-pci.sh;
  nativeBuildInputs = [ makeWrapper ];
  path = lib.makeBinPath [ coreutils pciutils kmod ];
} ''
  install -Dm 0755 $src $out/bin/reserve-pci
  patchShebangs $out/bin/*
  wrapProgram $out/bin/reserve-pci --prefix PATH : "$path"
''
