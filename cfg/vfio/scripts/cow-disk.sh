#!/usr/bin/env bash
set -eu

if [[ $1 = STOP ]]; then
	dmsetup remove $(cat $RUNTIME_DIRECTORY/dm)
	losetup -d $(cat $RUNTIME_DIRECTORY/loop)
	if [[ $(cat $RUNTIME_DIRECTORY/mode) = N ]]; then
		rm -f $(cat $RUNTIME_DIRECTORY/cow)
	fi
	exit
fi

DISK=$1
DM_NAME=$2
SNAP_MODE=$3
COW_TARGET_FILE=$4
SIZE_MB=$5

echo $DM_NAME > $RUNTIME_DIRECTORY/dm
echo $COW_TARGET_FILE > $RUNTIME_DIRECTORY/cow
echo $SNAP_MODE > $RUNTIME_DIRECTORY/mode

if [[ -e /dev/mapper/$DM_NAME ]]; then
	echo "nothing to do" >&2
	exit
fi

if [[ ! -e $COW_TARGET_FILE ]]; then
	dd if=/dev/null of=$COW_TARGET_FILE seek=$SIZE_MB bs=$((1024*1024)) count=0
fi

COW_TARGET=$(losetup --show -f $COW_TARGET_FILE)

echo $COW_TARGET > $RUNTIME_DIRECTORY/loop

CHUNKSIZE=16
BLOCK=$(basename $(readlink $DISK))
BLOCK_SIZE=$(cat /sys/class/block/$BLOCK/size)

dmsetup create $DM_NAME <<EOF
0 $BLOCK_SIZE snapshot $DISK $COW_TARGET $SNAP_MODE $CHUNKSIZE
EOF

echo $COW_TARGET
