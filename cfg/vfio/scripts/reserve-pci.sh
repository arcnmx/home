#!/usr/bin/env bash
set -eu

if [[ $1 = STOP ]]; then
	PCI_DEVICE=$(cat $RUNTIME_DIRECTORY/dev)
	echo > /sys/bus/pci/devices/$PCI_DEVICE/driver_override || true
	if [[ -e /sys/bus/pci/drivers/vfio-pci/$PCI_DEVICE ]]; then
		echo $PCI_DEVICE > /sys/bus/pci/drivers/vfio-pci/unbind
	fi
	exit
fi

PCI_DEVICE=$1
if [[ $PCI_DEVICE = ????:???? ]]; then
	PCI_DEVICE="0000:$(lspci -n -mm -d $PCI_DEVICE | cut -d ' ' -f 1)"
fi

echo $PCI_DEVICE > $RUNTIME_DIRECTORY/dev

for bound in /sys/bus/pci/drivers/{nvidia,snd_hda_intel}/$PCI_DEVICE; do
	if [[ -e $bound ]]; then
		echo $PCI_DEVICE > $(dirname "$bound")/unbind
	fi
done

if [[ ! -d /sys/bus/pci/drivers/vfio-pci ]]; then
	modprobe -a vfio vfio_iommu_type1 vfio_pci || true
fi

if [[ ! -e /sys/bus/pci/drivers/vfio-pci/$PCI_DEVICE ]]; then
	echo vfio-pci > /sys/bus/pci/devices/$PCI_DEVICE/driver_override
	echo $PCI_DEVICE > /sys/bus/pci/drivers/vfio-pci/bind
fi
