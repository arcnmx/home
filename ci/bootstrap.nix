let
  lockData = builtins.fromJSON (builtins.readFile ../flake.lock);
  sourceInfo = lockData.nodes.std.locked;
  src = fetchTarball {
    url = "https://github.com/${sourceInfo.owner}/${sourceInfo.repo}/archive/${sourceInfo.rev}.tar.gz";
    sha256 = sourceInfo.narHash;
  };
  std = import src;
  inherit (std) Flake List Set;
  inherit (Flake) Lock;
  lock = Lock.New (lockData // {
    override.sources = {
      ${lock.root} = toString ../.;
    };
  });
in {
  inherit std;
  inputs = Lock.Node.inputs (Lock.root lock);
  flake = Lock.outputs lock;
}
