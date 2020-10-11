{ ... }@args: let
  pwd = builtins.getEnv "PWD";
  pwd' = import pwd;
  pwd'' = if builtins.isFunction pwd' || pwd' ? __functor then pwd' args else pwd';
in if pwd != "" then pwd'' else throw "Can't determine CWD from environment"
