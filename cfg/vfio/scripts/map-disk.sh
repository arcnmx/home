#!/usr/bin/env bash
set -eu

if [[ $1 = STOP ]]; then
	dmsetup remove $(cat $RUNTIME_DIRECTORY/dm)
	losetup -d $(cat $RUNTIME_DIRECTORY/loop)
	if [[ -e $RUNTIME_DIRECTORY/diskloop ]]; then
		losetup -d $(cat $RUNTIME_DIRECTORY/diskloop)
	fi
	exit
fi

DISK=$1
DM_CONCISE=$2
DISK_ID=$3
DISK_TYPE=$4

DM_NAME=${DM_CONCISE%%,*}
echo $DM_NAME > $RUNTIME_DIRECTORY/dm

if [[ -e /dev/mapper/$DM_NAME ]]; then
	echo "nothing to do" >&2
	exit
fi

DFILE=$(readlink -f $DISK)
if [[ ! -b $DFILE ]]; then
	DFILE=$(losetup --show -f $DFILE)
	echo $DFILE > $RUNTIME_DIRECTORY/diskloop
fi

MBR_FILE=$RUNTIME_DIRECTORY/mbr
BLOCKDEV=$(basename $DFILE)
PARENTDEV=$(lsblk -no pkname $DFILE | tail -n1)
PARENT_SECTOR_SIZE=$(cat /sys/class/block/$PARENTDEV/queue/hw_sector_size || echo 512)
#BLOCK_START=$(cat /sys/class/block/$BLOCKDEV/start)
BLOCK_SIZE_512S=$(cat /sys/class/block/$BLOCKDEV/size)
# 2048 * 512-byte sectors = 1MB alignment
DISK_SIZE_512S=$(((BLOCK_SIZE_512S + 2048 + 2047) / 2048 * 2048))
BS=
dd if=/dev/zero of=$MBR_FILE bs=512 count=2048 status=none

LDEV=$(losetup --show -f $MBR_FILE)
echo $LDEV > $RUNTIME_DIRECTORY/loop

END_GUARD=$((DISK_SIZE_512S - 2048 - BLOCK_SIZE_512S))
if [[ $END_GUARD -ne 0 ]]; then
	END_GUARD="$((BLOCK_SIZE_512S + 2048)) $END_GUARD zero,"
else
	END_GUARD=
fi
DM_TABLE="
0 2048 linear $LDEV 0,
2048 $BLOCK_SIZE_512S linear $DFILE 0,
$END_GUARD
"
dmsetup create --concise "$DM_NAME,,,,$DM_TABLE"
CYL=$((DISK_SIZE_512S / 2048))
if [[ $CYL -gt 65535 ]]; then
	CYL=65535
fi
dmsetup setgeometry $DM_NAME $CYL 64 32 0
sfdisk --quiet --no-tell-kernel --no-reread /dev/mapper/$DM_NAME <<EOF
label: dos
label-id: 0x${DISK_ID::8}
device: $DM_NAME
unit: sectors
grain: $PARENT_SECTOR_SIZE
sector-size: $PARENT_SECTOR_SIZE

1 : start=$((2048*512/PARENT_SECTOR_SIZE)), size=$((BLOCK_SIZE_512S*512/PARENT_SECTOR_SIZE)), type=$DISK_TYPE
EOF
if [[ "$DM_NAME,,," != "$DM_CONCISE" ]]; then
	sleep 0.3
	dmsetup remove "$DM_NAME"
	dmsetup create --concise "$DM_CONCISE,$DM_TABLE"
fi
