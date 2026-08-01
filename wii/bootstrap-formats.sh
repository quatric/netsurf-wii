#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
OPTIONAL_ROOT="$SCRIPT_DIR/.deps/optional"
PREFIX="$OPTIONAL_ROOT/prefix"
HARU_SOURCE="$OPTIONAL_ROOT/libharu"
HARU_BUILD="$OPTIONAL_ROOT/libharu-build"

. "$SCRIPT_DIR/env.sh"

if ! "$DEVKITPRO/portlibs/ppc/bin/powerpc-eabi-pkg-config" \
		--exists libwebp 2>/dev/null; then
	echo "Missing devkitPro package ppc-libwebp." >&2
	echo "Install it with: sudo dkp-pacman -S ppc-libwebp" >&2
	exit 1
fi

mkdir -p "$OPTIONAL_ROOT" "$PREFIX"

if [ ! -d "$HARU_SOURCE/.git" ]; then
	git clone --branch v2.4.6 --depth 1 \
		https://github.com/libharu/libharu.git "$HARU_SOURCE"
fi

cmake -S "$HARU_SOURCE" -B "$HARU_BUILD" \
	-DCMAKE_TOOLCHAIN_FILE="$DEVKITPRO/cmake/Wii.cmake" \
	-DCMAKE_INSTALL_PREFIX="$PREFIX" \
	-DCMAKE_BUILD_TYPE=MinSizeRel \
	-DBUILD_SHARED_LIBS=OFF \
	-DLIBHPDF_EXAMPLES=OFF \
	-DPNG_PNG_INCLUDE_DIR="$DEVKITPRO/portlibs/ppc/include" \
	-DPNG_LIBRARY="$DEVKITPRO/portlibs/ppc/lib/libpng.a" \
	-DZLIB_INCLUDE_DIR="$DEVKITPRO/portlibs/ppc/include" \
	-DZLIB_LIBRARY="$DEVKITPRO/portlibs/ppc/lib/libz.a"
cmake --build "$HARU_BUILD" --parallel
cmake --install "$HARU_BUILD"

echo "Installed WebP and Haru PDF dependencies in $PREFIX"
