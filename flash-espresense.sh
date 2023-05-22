#!/usr/bin/env bash
set -eu

BASEURL=https://espresense.com
BUILD_ROOT=build/espresense
VERSION_NAME_FALLBACK=v3.2.4
VERSION_NAME=$(curl -fsL https://api.github.com/repos/ESPresense/ESPresense/releases/latest | jq -er .name || echo $VERSION_NAME_FALLBACK)
MANIFEST_NAME=${VERSION_NAME}.json
VERBOSE=${VERBOSE-}

mkdir -p "$BUILD_ROOT"
if [[ -e "$BUILD_ROOT/$MANIFEST_NAME" ]]; then
	MANIFEST=$(cat "$BUILD_ROOT/$MANIFEST_NAME")
else
	MANIFEST=$(curl -fsL "$BASEURL/releases/$MANIFEST_NAME")
	printf %s "$MANIFEST" > "$BUILD_ROOT/$MANIFEST_NAME"
fi

echo ESPresense $VERSION_NAME >&2

BUILD=$(jq '.builds[] | select(.chipFamily=="ESP32")' <<<"$MANIFEST")
PARTS=$(jq '.parts[]' <<<"$BUILD")

WRITE_FLASH_ARGS=(write_flash --verify)
while read offset; do
	read path
	if [[ -n $VERBOSE && $path = */esp32.bin ]]; then
		path=${path/esp32/esp32-verbose}
	fi
	localpath="$BUILD_ROOT/$path"
	if [[ $path = /* ]]; then
		url="$BASEURL$path"
	else
		url="$BASEURL/releases/$path"
	fi
	if ! [[ -e "$localpath" ]]; then
		echo Downloading $localpath >&2
		mkdir -p "$(dirname "$localpath")"
		curl -fLo "$localpath" "$url"
	fi
	WRITE_FLASH_ARGS+=($offset "$BUILD_ROOT/$path")
done < <(jq -er '.offset, .path' <<<"$PARTS")

esptool.py \
	--chip esp32 \
	"${WRITE_FLASH_ARGS[@]}" "$@"
