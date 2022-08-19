{ runCommand
, lib
, makeWrapper
, coreutils, forcefully-remove-bootfb
}: runCommand "unbind-vts" {
  src = ./unbind-vts.sh;
  nativeBuildInputs = [ makeWrapper ];
  path = lib.makeBinPath [ coreutils forcefully-remove-bootfb.bin ];
} ''
  install -Dm 0755 $src $out/bin/unbind-vts
  patchShebangs $out/bin/*
  wrapProgram $out/bin/unbind-vts --prefix PATH : "$path"
''
