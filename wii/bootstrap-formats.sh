#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
OPTIONAL_ROOT="$SCRIPT_DIR/.deps/optional"
PREFIX="$OPTIONAL_ROOT/prefix"
HARU_SOURCE="$OPTIONAL_ROOT/libharu"
HARU_BUILD="$OPTIONAL_ROOT/libharu-build"
JXL_SOURCE="$OPTIONAL_ROOT/libjxl"
JXL_BUILD="$OPTIONAL_ROOT/libjxl-build"

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

if [ ! -d "$JXL_SOURCE/.git" ]; then
	git clone --branch v0.11.2 --depth 1 \
		https://github.com/libjxl/libjxl.git "$JXL_SOURCE"
	git -C "$JXL_SOURCE" submodule update --init --depth 1 \
		third_party/highway third_party/lcms
fi

cmake -S "$JXL_SOURCE" -B "$JXL_BUILD" \
	-DCMAKE_TOOLCHAIN_FILE="$DEVKITPRO/cmake/Wii.cmake" \
	-DCMAKE_INSTALL_PREFIX="$PREFIX" \
	-DCMAKE_BUILD_TYPE=MinSizeRel \
	-DBUILD_SHARED_LIBS=OFF \
	-DBUILD_TESTING=OFF \
	-DATOMICS_LOCK_FREE_INSTRUCTIONS=TRUE \
	-DJPEGXL_ENABLE_TOOLS=OFF \
	-DJPEGXL_ENABLE_DEVTOOLS=OFF \
	-DJPEGXL_ENABLE_JPEGLI=OFF \
	-DJPEGXL_ENABLE_JPEGLI_LIBJPEG=OFF \
	-DJPEGXL_ENABLE_DOXYGEN=OFF \
	-DJPEGXL_ENABLE_MANPAGES=OFF \
	-DJPEGXL_ENABLE_BENCHMARK=OFF \
	-DJPEGXL_ENABLE_EXAMPLES=OFF \
	-DJPEGXL_ENABLE_JNI=OFF \
	-DJPEGXL_ENABLE_SJPEG=OFF \
	-DJPEGXL_ENABLE_OPENEXR=OFF \
	-DJPEGXL_ENABLE_SKCMS=OFF \
	-DJPEGXL_ENABLE_TCMALLOC=OFF \
	-DJPEGXL_ENABLE_PLUGINS=OFF \
	-DJPEGXL_ENABLE_TRANSCODE_JPEG=OFF \
	-DJPEGXL_FORCE_SYSTEM_BROTLI=ON \
	-DJPEGXL_FORCE_SYSTEM_LCMS2=OFF \
	-DBROTLI_INCLUDE_DIR="$DEVKITPRO/portlibs/ppc/include"

# Building only the decoder libraries avoids Highway's host-side test tools,
# which require 64-bit atomic helpers not supplied by devkitPPC/newlib.
cmake --build "$JXL_BUILD" --parallel --target jxl jxl_threads
cmake --install "$JXL_BUILD"
cp "$JXL_BUILD/third_party/liblcms2.a" "$PREFIX/lib/liblcms2.a"

echo "Installed WebP, JPEG XL, and Haru PDF dependencies in $PREFIX"
