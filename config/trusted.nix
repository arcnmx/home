{ lib
, trustedPath ? ./profiles/trusted
, enable ? builtins.pathExists (trustedPath + "/meta.nix")
}: with lib; let
  importModule = root: let
    f = path: if path == "default" then trustedPath + "/${root}.nix" else trustedPath + "/${path}.nix";
  in path: lib.optional enable (f path);
in {
  inherit enable;
  import = {
    nixos = importModule "nixos";
    home = importModule "home";
    meta = importModule "meta";
  };
}
