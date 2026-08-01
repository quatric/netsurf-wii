#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
SOURCE_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
SUPPORT_PREFIX="$SCRIPT_DIR/.deps/netsurf-workspace/inst-powerpc-eabi"
NETWORK_PREFIX="$SCRIPT_DIR/.deps/network"
ICONV_PREFIX="$SCRIPT_DIR/.deps/iconv"
OPTIONAL_PREFIX="$SCRIPT_DIR/.deps/optional/prefix"
INPUT_PREFIX="$SCRIPT_DIR/.deps/input/prefix"
HOST_BUILD=$(cc -dumpmachine 2>/dev/null || printf '%s' arm64-apple-darwin)
HOST_TOOL_PREFIX="$SCRIPT_DIR/.deps/netsurf-workspace/inst-$HOST_BUILD"
PACKAGE_DIR="$SCRIPT_DIR/dist/apps/netsurf"
RODIN_FONT_DIR=${RODIN_FONT_DIR:-"$HOME/Library/Fonts"}
RODIN_REGULAR_SOURCE=${RODIN_REGULAR_SOURCE:-"$RODIN_FONT_DIR/FOT-RodinNTLGPro-M.otf"}
RODIN_BOLD_SOURCE=${RODIN_BOLD_SOURCE:-"$RODIN_FONT_DIR/FOT-RodinNTLGPro-B.otf"}

. "$SCRIPT_DIR/env.sh"
for tool_dir in /opt/homebrew/opt/bison/bin /opt/homebrew/opt/flex/bin; do
	if [ -d "$tool_dir" ]; then
		PATH="$tool_dir:$PATH"
	fi
done
export PATH
PATH="$HOST_TOOL_PREFIX/bin:$PATH"
export PATH

for required in \
	"$SUPPORT_PREFIX/lib/pkgconfig/libnsfb.pc" \
	"$NETWORK_PREFIX/lib/libcurl.a" \
	"$ICONV_PREFIX/lib/libiconv.a" \
	"$OPTIONAL_PREFIX/lib/libhpdf.a" \
	"$OPTIONAL_PREFIX/lib/libjxl.a" \
	"$INPUT_PREFIX/lib/libwupc.a" \
	"$INPUT_PREFIX/include/wupc/wupc.h" \
	"$HOST_TOOL_PREFIX/bin/nsgenbind" \
	"$RODIN_REGULAR_SOURCE" \
	"$RODIN_BOLD_SOURCE" \
	"$SCRIPT_DIR/cacert.pem"; do
	if [ ! -f "$required" ]; then
		echo "Missing browser dependency: $required" >&2
		echo "See wii/README.md for the bootstrap procedure." >&2
		exit 1
	fi
done

cp "$SCRIPT_DIR/Makefile.config.wii" "$SOURCE_ROOT/Makefile.config"

export PKG_CONFIG_LIBDIR="$OPTIONAL_PREFIX/lib/pkgconfig:$SUPPORT_PREFIX/lib/pkgconfig:$NETWORK_PREFIX/lib/pkgconfig:$DEVKITPRO/portlibs/wii/lib/pkgconfig:$DEVKITPRO/portlibs/ppc/lib/pkgconfig"
export CFLAGS="-DBUILDING_LIBICONV=0 -DGEKKO -I$INPUT_PREFIX/include -I$OPTIONAL_PREFIX/include -I$ICONV_PREFIX/include -I$NETWORK_PREFIX/include -I$SUPPORT_PREFIX/include -I$DEVKITPRO/libogc/include -I$DEVKITPRO/portlibs/wii/include -I$DEVKITPRO/portlibs/ppc/include -mrvl -mcpu=750 -meabi -mhard-float"
export LDFLAGS="-L$INPUT_PREFIX/lib -L$OPTIONAL_PREFIX/lib -L$ICONV_PREFIX/lib -L$NETWORK_PREFIX/lib -L$SUPPORT_PREFIX/lib -L$DEVKITPRO/libogc/lib/wii -L$DEVKITPRO/portlibs/wii/lib -L$DEVKITPRO/portlibs/ppc/lib -mrvl -mcpu=750 -meabi -mhard-float"
export NETSURF_BUILD_USER=quatric
export NETSURF_BUILD_NAME=quatric
export NETSURF_BUILD_ROOT=netsurf-wii
export HOSTNAME=wii-build

BUILD_LIBPNG_CFLAGS=$(pkg-config --cflags libpng)
BUILD_LIBPNG_LDFLAGS=$(pkg-config --libs libpng)

make -C "$SOURCE_ROOT" \
	TARGET=framebuffer HOST=powerpc-eabi \
	CC=powerpc-eabi-gcc CXX=powerpc-eabi-g++ \
	PKG_CONFIG="$SCRIPT_DIR/powerpc-eabi-ns-pkg-config" \
	BUILD_LIBPNG_CFLAGS="$BUILD_LIBPNG_CFLAGS" \
	BUILD_LIBPNG_LDFLAGS="$BUILD_LIBPNG_LDFLAGS" \
	"$@"

mkdir -p "$PACKAGE_DIR"
elf2dol "$SOURCE_ROOT/nsfb" "$PACKAGE_DIR/boot.dol"
if ! grep -Fq '<coder>quatric</coder>' "$SCRIPT_DIR/meta.xml"; then
	echo "Refusing to package meta.xml without the quatric coder credit" >&2
	exit 1
fi

cp "$SCRIPT_DIR/meta.xml" "$SCRIPT_DIR/icon.png" "$SCRIPT_DIR/cacert.pem" \
	"$SCRIPT_DIR/js-smoke.html" "$PACKAGE_DIR/"

for resource in adblock.css credits.html default.css internal.css \
	licence.html netsurf.png quirks.css welcome.html; do
	cp -L "$SOURCE_ROOT/frontends/framebuffer/res/$resource" "$PACKAGE_DIR/"
done
cp "$SOURCE_ROOT/frontends/framebuffer/res/en/Messages" \
	"$PACKAGE_DIR/Messages"
mkdir -p "$PACKAGE_DIR/fonts"
cp "$RODIN_REGULAR_SOURCE" "$PACKAGE_DIR/fonts/RodinNTLG-M.otf"
cp "$RODIN_BOLD_SOURCE" "$PACKAGE_DIR/fonts/RodinNTLG-B.otf"
chmod 0644 "$PACKAGE_DIR/fonts/RodinNTLG-M.otf" \
	"$PACKAGE_DIR/fonts/RodinNTLG-B.otf"

echo "Packaged Wii browser at $PACKAGE_DIR"
