{ lib, ... }: with lib; {
  # https://github.com/arcnmx/ci
  name = "home";
  ci.gh-actions.enable = true;

  # eventually have this not use the nx wrapper...
  ci.gh-actions.export = true;
  gh-actions.jobs.ci.step = let
    hostnames = [ "satorin" "shanghai" ];
    profiles = hostnames ++ [ "base" "personal" "desktop" "laptop" ];
  in mapAttrs' (k: nameValuePair "nixos-${k}") (genAttrs hostnames (host: {
    name = "build nixos/${host}";
    run = ''
      ./nx switch ${host} build --show-trace
    '';
  })) // mapAttrs' (k: nameValuePair "home-${k}") (genAttrs profiles (host: {
    name = "build home/${host}";
    run = ''
      ./nx home ${host} build --show-trace
    '';
  })) // {
    submodules = {
      # nixpkgs is too big and takes too long to download, so...
      order = 20;
      name = "git submodule init";
      run = ''
        gh_submodule() {
          SUBMODULE_COMMIT=$(git submodule status $1 | cut -d ' ' -f 1)
          curl -fSL https://github.com/$2/archive/''${SUBMODULE_COMMIT#-}.tar.gz | tar -xz --strip-components=1 -C $1
        }

        git submodule update --init channels/{arc,home-manager,rust,mozilla,nur}
        gh_submodule channels/nixpkgs nixos/nixpkgs
      '';
    };
  };
  ci.gh-actions.checkoutOptions.submodules = false;

  cache.cachix.arc = {
    enable = true;
    publicKey = "arc.cachix.org-1:DZmhclLkB6UO0rc0rBzNpwFbbaeLfyn+fYccuAy7YVY=";
  };
}
