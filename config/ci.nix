{ cipkgs, ... } @ ci: {
  # https://github.com/arcnmx/ci

  allowRoot = (builtins.getEnv "CI_ALLOW_ROOT") != "";
  closeStdin = (builtins.getEnv "CI_CLOSE_STDIN") != "";

  cache.cachix = {
    arc = { };
  };
}
