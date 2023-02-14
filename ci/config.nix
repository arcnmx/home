{ lib, ... }: with lib; {
  # https://github.com/arcnmx/ci
  name = "home";
  ci.gh-actions.enable = true;
  jobs = let
    home = import ../. { };
    hostnames = [ "satorin" "shanghai" ];
  in mapAttrs' (k: nameValuePair "nixos-${k}") (genAttrs hostnames (host: let
    inherit (home.network.nodes.${host}.deploy) system;
  in {
    ci.gh-actions.name = mkForce "build nixos/${host}";
    tasks.nixos.inputs = [ system ];
  }));
  ci.gh-actions.checkoutOptions.submodules = false;

  cache.cachix = {
    ci.signingKey = "";
    arc = {
      enable = true;
      publicKey = "arc.cachix.org-1:DZmhclLkB6UO0rc0rBzNpwFbbaeLfyn+fYccuAy7YVY=";
    };
  };
}
