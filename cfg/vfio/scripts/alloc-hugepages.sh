#!/usr/bin/env bash
set -eu

HUGEPAGES_2M=$1
HUGEPAGES_1G=$2

echo 3 > /proc/sys/vm/drop_caches || true
echo 1 > /proc/sys/vm/compact_memory || true

if [[ $HUGEPAGES_2M -gt 0 ]]; then
	if [[ ! -d /dev/hugpages ]]; then
		systemctl start dev-hugepages.mount
	fi
	echo $HUGEPAGES_2M > /sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages || true
fi

if [[ $HUGEPAGES_1G -gt 0 ]]; then
	if [[ ! -d /dev/hugpages1G ]]; then
		systemctl start dev-hugepages1G.mount
	fi
	echo $HUGEPAGES_1G > /sys/kernel/mm/hugepages/hugepages-1048576kB/nr_hugepages || true
fi
