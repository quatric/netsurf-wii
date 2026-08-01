#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DEPS_ROOT="$SCRIPT_DIR/.deps"
WORKSPACE="$DEPS_ROOT/netsurf-workspace"
PREFIX="$WORKSPACE/inst-powerpc-eabi"
ICONV_PREFIX="$DEPS_ROOT/iconv"
INPUT_PREFIX="$DEPS_ROOT/input/prefix"
BUILD_SYSTEM="$WORKSPACE/buildsystem"
HOST_BUILD=$(cc -dumpmachine 2>/dev/null || printf '%s' arm64-apple-darwin)

. "$SCRIPT_DIR/env.sh"
for tool_dir in /opt/homebrew/opt/bison/bin /opt/homebrew/opt/flex/bin; do
	if [ -d "$tool_dir" ]; then
		PATH="$tool_dir:$PATH"
	fi
done
export PATH
"$SCRIPT_DIR/bootstrap-network.sh"
"$SCRIPT_DIR/bootstrap-formats.sh"
"$SCRIPT_DIR/bootstrap-input.sh"
mkdir -p "$WORKSPACE" "$PREFIX"

clone_at() {
	name=$1
	revision=$2
	directory="$WORKSPACE/$name"
	if [ ! -d "$directory/.git" ]; then
		git clone "https://github.com/NetSurf-browser/$name.git" "$directory"
		git -C "$directory" checkout --detach "$revision"
	fi
}

clone_at buildsystem 0005ae300283
clone_at libwapcaplet c7c128d3eb32
clone_at libparserutils 6b0cbf086ca8
clone_at libhubbub 6651b8cf87a4
clone_at libdom f69781e1f062
clone_at libcss 58bff86fa858
clone_at libnsgif 5d5d750f3275
clone_at libnsbmp ea063c9f46ac
clone_at libnsutils 0bd39060740b
clone_at libnspsl 82815c2bc7fd
clone_at libnslog bedff2146270
clone_at libsvgtiny 073283b29dd8
clone_at libnsfb b701cdce7241
clone_at nsgenbind 44c6736937ae

# NetSurf's buildsystem assumes Linux has /bin/which. macOS does not.
sed -i.bak 's#$(shell /bin/which $(CC__))#$(shell command -v $(CC__))#' \
	"$BUILD_SYSTEM/makefiles/Makefile.tools"
if git -C "$WORKSPACE/libnsfb" apply --check \
		"$SCRIPT_DIR/patches/libnsfb-wii-endian.patch" 2>/dev/null; then
	git -C "$WORKSPACE/libnsfb" apply \
		"$SCRIPT_DIR/patches/libnsfb-wii-endian.patch"
fi

ICONV_ARCHIVE="$DEPS_ROOT/downloads/libiconv-1.19.tar.gz"
ICONV_SOURCE="$DEPS_ROOT/libiconv-1.19"
mkdir -p "$DEPS_ROOT/downloads"
if [ ! -f "$ICONV_ARCHIVE" ]; then
	curl -fL https://ftp.gnu.org/pub/gnu/libiconv/libiconv-1.19.tar.gz \
		-o "$ICONV_ARCHIVE"
fi
ICONV_HASH=$(shasum -a 256 "$ICONV_ARCHIVE" | awk '{print $1}')
if [ "$ICONV_HASH" != \
		"88dd96a8c0464eca144fc791ae60cd31cd8ee78321e67397e25fc095c4a19aa6" ]; then
	echo "Checksum mismatch for libiconv-1.19.tar.gz" >&2
	exit 1
fi
if [ ! -d "$ICONV_SOURCE" ]; then
	tar -xzf "$ICONV_ARCHIVE" -C "$DEPS_ROOT"
fi
if [ ! -f "$ICONV_PREFIX/lib/libiconv.a" ]; then
	(
		cd "$ICONV_SOURCE"
		./configure --host=powerpc-eabi --prefix="$ICONV_PREFIX" \
			--enable-static --disable-shared \
			CC=powerpc-eabi-gcc AR=powerpc-eabi-ar \
			RANLIB=powerpc-eabi-ranlib \
			CFLAGS="-DGEKKO -mrvl -mcpu=750 -meabi -mhard-float"
		make -C libcharset install
		make -C lib install CPPFLAGS="-I$ICONV_PREFIX/include"
	)
	cp "$ICONV_SOURCE/include/iconv.h" "$ICONV_PREFIX/include/iconv.h"
fi

export PKG_CONFIG_LIBDIR="$PREFIX/lib/pkgconfig:$SCRIPT_DIR/.deps/network/lib/pkgconfig:$DEVKITPRO/portlibs/wii/lib/pkgconfig:$DEVKITPRO/portlibs/ppc/lib/pkgconfig"
export CFLAGS="-DBUILDING_LIBICONV=0 -DGEKKO -I$ICONV_PREFIX/include -I$INPUT_PREFIX/include -I$SCRIPT_DIR/.deps/network/include -I$PREFIX/include -I$DEVKITPRO/libogc/include -I$DEVKITPRO/portlibs/wii/include -I$DEVKITPRO/portlibs/ppc/include -mrvl -mcpu=750 -meabi -mhard-float"
export LDFLAGS="-L$ICONV_PREFIX/lib -L$SCRIPT_DIR/.deps/network/lib -L$PREFIX/lib -L$DEVKITPRO/libogc/lib/wii -L$DEVKITPRO/portlibs/wii/lib -L$DEVKITPRO/portlibs/ppc/lib -mrvl -mcpu=750 -meabi -mhard-float"

for library in libwapcaplet libparserutils libhubbub libdom libcss \
	libnsgif libnsbmp libnsutils libnspsl libnslog libsvgtiny libnsfb; do
	make -C "$WORKSPACE/$library" install \
		NSSHARED="$BUILD_SYSTEM" HOST=powerpc-eabi BUILD="$HOST_BUILD" \
		CC=powerpc-eabi-gcc AR=powerpc-eabi-ar \
		PKG_CONFIG="$SCRIPT_DIR/powerpc-eabi-ns-pkg-config" \
		PREFIX="$PREFIX" VARIANT=release
done

HOST_PREFIX="$WORKSPACE/inst-$HOST_BUILD"
(
	unset CFLAGS LDFLAGS
	make -C "$WORKSPACE/nsgenbind" install \
		NSSHARED="$BUILD_SYSTEM" HOST="$HOST_BUILD" BUILD="$HOST_BUILD" \
		PREFIX="$HOST_PREFIX" VARIANT=release
)

echo "Installed browser support libraries in $PREFIX"
