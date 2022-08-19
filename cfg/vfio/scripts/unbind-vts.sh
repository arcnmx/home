#!/usr/bin/env bash
set -eu

for vt in /sys/class/vtconsole/*; do
	if [[ -e $vt ]]; then
		echo 0 > $vt/bind || true
	fi
done
for fb in /sys/devices/platform/{efi,simple}-framebuffer.*; do
	if [[ -e $fb && -e $fb/driver/unbind ]]; then
		echo $(basename "$fb") > $fb/driver/unbind || true
	fi
done
forcefully-remove-bootfb || true
