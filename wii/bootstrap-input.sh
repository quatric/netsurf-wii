#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
SOURCE_DIR="$SCRIPT_DIR/.deps/input/libwupc"
PREFIX="$SCRIPT_DIR/.deps/input/prefix"
REVISION=24145b35dbc2c1950f6f48079d577acc7efb0c4d
LIBINPUT_DIR="$SCRIPT_DIR/.deps/input/libinput-wii"
LIBINPUT_REVISION=226df940c34d255e15d500da4bfae52d94d8bd82

. "$SCRIPT_DIR/env.sh"

if [ ! -d "$SOURCE_DIR/.git" ]; then
	mkdir -p "$(dirname -- "$SOURCE_DIR")"
	git clone https://github.com/FIX94/libwupc.git "$SOURCE_DIR"
	git -C "$SOURCE_DIR" checkout --detach "$REVISION"
fi

if git -C "$SOURCE_DIR" apply --check \
		"$SCRIPT_DIR/patches/libwupc-libogc-3.patch" 2>/dev/null; then
	git -C "$SOURCE_DIR" apply \
		"$SCRIPT_DIR/patches/libwupc-libogc-3.patch"
fi

# The repository ships a prebuilt, unpatched lib/libwupc.a. Make with
# one-second timestamps (macOS's make 3.81) can take it as newer than the
# freshly compiled object, so remove it to always build from the patched source.
rm -f "$SOURCE_DIR/lib/libwupc.a"
make -C "$SOURCE_DIR"
mkdir -p "$PREFIX/include/wupc" "$PREFIX/lib"
cp "$SOURCE_DIR/include/wupc/wupc.h" "$PREFIX/include/wupc/wupc.h"
cp "$SOURCE_DIR/lib/libwupc.a" "$PREFIX/lib/libwupc.a"

# libinput-wii: controller scanning and mapping for the libnsfb patch, built
# against the libwupc just installed.
if [ ! -d "$LIBINPUT_DIR/.git" ]; then
	mkdir -p "$(dirname -- "$LIBINPUT_DIR")"
	git clone https://github.com/quatric/libinput-wii.git "$LIBINPUT_DIR"
fi
if [ "$(git -C "$LIBINPUT_DIR" rev-parse HEAD)" != "$LIBINPUT_REVISION" ]; then
	git -C "$LIBINPUT_DIR" fetch origin
	git -C "$LIBINPUT_DIR" checkout --detach "$LIBINPUT_REVISION"
	make -C "$LIBINPUT_DIR" clean
fi
make -C "$LIBINPUT_DIR" WITH_WUPC=1 PORTLIBS="$PREFIX"
cp "$LIBINPUT_DIR/lib/libinput-wii.a" "$PREFIX/lib/libinput-wii.a"
cp "$LIBINPUT_DIR/include/input_wii.h" "$PREFIX/include/input_wii.h"

echo "Installed Wii U Pro Controller support and libinput-wii in $PREFIX"
