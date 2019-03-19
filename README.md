A combination of system config, dotfiles, and personal Nix package repo/channel/whatever. Tries to rely on the external environment as little as possible - nixpkgs and other channels are pinned as submodules under the `channels/` directory.

## NixOS

```bash
./nx exec switch.nix switch hostName=whatever

# shorthand for deploying to current machine:
./nx switch
```

## Nix

```bash
nix run -f run.nix home-manager -c home-manager -f home.nix -A $(hostname -s) switch
```
