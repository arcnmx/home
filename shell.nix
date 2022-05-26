(import ./ci/bootstrap.nix).outputs.devShells.${builtins.currentSystem or "x86_64-linux"}.default
