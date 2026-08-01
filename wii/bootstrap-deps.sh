#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DEPS_ROOT="$SCRIPT_DIR/.deps"
BUILD_SYSTEM="$DEPS_ROOT/buildsystem"
LIBNSFB="$DEPS_ROOT/libnsfb"
HOST_BUILD=$(cc -dumpmachine 2>/dev/null || printf '%s' arm64-apple-darwin)

. "$SCRIPT_DIR/env.sh"
"$SCRIPT_DIR/bootstrap-network.sh"
"$SCRIPT_DIR/bootstrap-input.sh"
INPUT_PREFIX="$DEPS_ROOT/input/prefix"

mkdir -p "$DEPS_ROOT"
if [ ! -d "$BUILD_SYSTEM/.git" ]; then
	git clone https://github.com/NetSurf-browser/buildsystem.git "$BUILD_SYSTEM"
fi
if [ ! -d "$LIBNSFB/.git" ]; then
	git clone https://github.com/NetSurf-browser/libnsfb.git "$LIBNSFB"
fi

# NetSurf's buildsystem assumes Linux has /bin/which. macOS does not.
sed -i.bak 's#$(shell /bin/which $(CC__))#$(shell command -v $(CC__))#' \
	"$BUILD_SYSTEM/makefiles/Makefile.tools"

if git -C "$LIBNSFB" apply --check \
		"$SCRIPT_DIR/patches/libnsfb-wii-endian.patch" 2>/dev/null; then
	git -C "$LIBNSFB" apply "$SCRIPT_DIR/patches/libnsfb-wii-endian.patch"
fi

WII_CFLAGS="-DGEKKO -D_BSD_SOURCE -D_DEFAULT_SOURCE \
-D_POSIX_C_SOURCE=200112L -I$LIBNSFB/include -I$LIBNSFB/src \
-I$INPUT_PREFIX/include \
-I$DEVKITPRO/libogc/include -I$DEVKITPRO/portlibs/wii/include \
-I$DEVKITPRO/portlibs/ppc/include -mrvl -mcpu=750 -meabi \
-mhard-float -std=c99"

make -C "$LIBNSFB" \
	NSSHARED="$BUILD_SYSTEM" \
	HOST=powerpc-eabi BUILD="$HOST_BUILD" \
	CC="$DEVKITPPC/bin/powerpc-eabi-gcc" \
	AR="$DEVKITPPC/bin/powerpc-eabi-ar" \
	PKGCONFIG="$DEVKITPRO/portlibs/wii/bin/powerpc-eabi-pkg-config" \
	CFLAGS="$WII_CFLAGS" VARIANT=release

mkdir -p "$LIBNSFB/prefix/lib" "$LIBNSFB/prefix/include"
cp "$LIBNSFB"/build-*powerpc-eabi-release-lib-static/libnsfb.a \
	"$LIBNSFB/prefix/lib/libnsfb.a"
cp "$LIBNSFB"/include/libnsfb*.h "$LIBNSFB/prefix/include/"
