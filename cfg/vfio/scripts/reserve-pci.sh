#!/usr/bin/env bash
set -eu

if [[ $1 = STOP ]]; then
	device=$(cat $RUNTIME_DIRECTORY/dev)
	echo > /sys/bus/pci/devices/0000:$device/driver_override || true
	if [[ -e /sys/bus/pci/drivers/vfio-pci/0000:$device ]]; then
		echo 0000:$device > /sys/bus/pci/drivers/vfio-pci/unbind
	fi
	exit
fi

PCI_DEVICE=$1
device=$(lspci -n -mm -d $PCI_DEVICE | cut -d ' ' -f 1)

echo $device > $RUNTIME_DIRECTORY/dev

for bound in /sys/bus/pci/drivers/{nvidia,snd_hda_intel}/0000:$device; do
	if [[ -e $bound ]]; then
		echo 0000:$device > $(dirname "$bound")/unbind
	fi
done

if [[ ! -d /sys/bus/pci/drivers/vfio-pci ]]; then
	modprobe -a vfio vfio_iommu_type1 vfio_pci vfio_virqfd || true
fi

if [[ ! -e /sys/bus/pci/drivers/vfio-pci/0000:$device ]]; then
	echo vfio-pci > /sys/bus/pci/devices/0000:$device/driver_override
	echo 0000:$device > /sys/bus/pci/drivers/vfio-pci/bind
fi
