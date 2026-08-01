#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
SOURCE_DIR="$SCRIPT_DIR/.deps/input/libwupc"
PREFIX="$SCRIPT_DIR/.deps/input/prefix"
REVISION=24145b35dbc2c1950f6f48079d577acc7efb0c4d

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

make -C "$SOURCE_DIR"
mkdir -p "$PREFIX/include/wupc" "$PREFIX/lib"
cp "$SOURCE_DIR/include/wupc/wupc.h" "$PREFIX/include/wupc/wupc.h"
cp "$SOURCE_DIR/lib/libwupc.a" "$PREFIX/lib/libwupc.a"

echo "Installed Wii U Pro Controller support in $PREFIX"
