{ lib, ... }: with lib; {
  # https://github.com/arcnmx/ci
  name = "home";
  ci.gh-actions.enable = true;

  ci.gh-actions.export = true;
  gh-actions.jobs.ci.step = let
    hostnames = [ "satorin" "shanghai" ];
    profiles = [ /*"base" "personal" "desktop" "laptop"*/ ];
  in mapAttrs' (k: nameValuePair "nixos-${k}") (genAttrs hostnames (host: {
    name = "build nixos/${host}";
    run = ''
      nix build -Lf. network.nodes.${host}.deploy.system --show-trace
    '';
  })) // mapAttrs' (k: nameValuePair "home-${k}") (genAttrs profiles (profile: {
    name = "build home/${profile}";
    run = ''
      nix build -Lf. home.profiles.${profile}.deploy.home --show-trace
    '';
  }));
  ci.gh-actions.checkoutOptions.submodules = false;

  cache.cachix.arc = {
    enable = true;
    publicKey = "arc.cachix.org-1:DZmhclLkB6UO0rc0rBzNpwFbbaeLfyn+fYccuAy7YVY=";
  };
}
