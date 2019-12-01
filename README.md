A combination of system config, dotfiles, and personal Nix package repo/channel/whatever. Tries to rely on the external environment as little as possible - nixpkgs and other channels are pinned as submodules under the `channels/` directory.

## NixOS

Installation from nixos installer:

```bash
HOSTNAME=$(hostname -s) # fill in here
./nx switch $HOSTNAME build &&
sudo nixos-install --root /mnt --system $PWD/result-gensokyo-$HOSTNAME/
```

## Nix

```bash
./nx home $(hostname -s) switch
```
