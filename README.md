A combination of system config, dotfiles, and personal Nix package repo/channel/whatever. Tries to rely on the external environment as little as possible - nixpkgs and other channels are pinned as submodules under the `channels/` directory.

## NixOS

```bash
./nx switch $(hostname -s) switch
```

## Nix

```bash
./nx home $(hostname -s) switch
```
