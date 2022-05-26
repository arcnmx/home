let
  lock = builtins.fromJSON (builtins.readFile ../flake.lock);
  sourceInfo = lock.nodes.std.locked;
  src = fetchTarball {
    url = "https://github.com/${sourceInfo.owner}/${sourceInfo.repo}/archive/${sourceInfo.rev}.tar.gz";
    sha256 = sourceInfo.narHash;
  };
  std = import src;
  inherit (std) Flake List Set;
  srcs = Set.map (_: node: Flake.Source.fetch (Flake.Lock.Node.sourceInfo node)) lock.nodes // {
    ${lock.root} = toString ../.;
  };
  nodeInputs = Set.map (_: node: Set.map (_: nodename: Set.at (List.From nodename) flakes) node.inputs or { }) lock.nodes;
  callFlake = name: node: let
    sourceInfo = node.locked or { } // {
      outPath = srcs.${name};
    };
    inputs = nodeInputs.${name};
    outputs = Flake.CallDir sourceInfo.outPath inputs;
  in sourceInfo // Set.optional node.flake or true ({ inherit sourceInfo inputs outputs; } // outputs);
  flakes = Set.map callFlake lock.nodes;
in {
  inherit std;
  inputs = nodeInputs.${lock.root};
  flake = flakes.${lock.root};
}
