#!/bin/sh
# Compress a Wii .dol into a self-extracting xz .dol with FIX94's dolxz
# (https://github.com/FIX94/dolxz, MIT; its loader stub also carries GPL-2.0
# code from Segher Boessenkool's dolloader and public-domain xz-embedded).
#
# usage: dolxz.sh <in.dol> <out.dol> [extra dolxz options, e.g. -high]
#
# dolxz is fetched at a pinned commit and built once into $DOLXZ_CACHE
# (default: .dolxz next to this script's parent directory). Building it needs
# devkitPPC ($DEVKITPRO/$DEVKITPPC), elf2dol, a host C compiler and liblzma
# (Debian/Ubuntu: liblzma-dev; macOS: brew install xz).
#
# Set DOLXZ_SRC to an existing dolxz checkout to build without network access.
set -eu

DOLXZ_COMMIT=bf73653618facd06c1f5c98e81215d2298aefc40

if [ $# -lt 2 ]; then
    echo "usage: $0 <in.dol> <out.dol> [dolxz options]" >&2
    exit 2
fi
in=$1
out=$2
shift 2

here=$(cd "$(dirname "$0")" && pwd)
: "${DEVKITPRO:=/opt/devkitpro}"
: "${DEVKITPPC:=$DEVKITPRO/devkitPPC}"
: "${DOLXZ_CACHE:=$(dirname "$here")/.dolxz}"
: "${HOSTCC:=cc}"

root=$DOLXZ_CACHE/$DOLXZ_COMMIT
tool=$root/dolxz

build_dolxz() {
    rm -rf "$root.tmp"
    mkdir -p "$root.tmp"
    src=$root.tmp/src
    if [ -n "${DOLXZ_SRC:-}" ]; then
        cp -R "$DOLXZ_SRC" "$src"
    else
        url=https://github.com/FIX94/dolxz/archive/$DOLXZ_COMMIT.tar.gz
        if command -v curl >/dev/null 2>&1; then
            curl -fsSL "$url" -o "$root.tmp/src.tar.gz"
        else
            wget -q "$url" -O "$root.tmp/src.tar.gz"
        fi
        mkdir "$src"
        tar -xzf "$root.tmp/src.tar.gz" -C "$src" --strip-components=1
    fi

    # The sources include <malloc.h> and rely on implicit string/errno
    # declarations; give the host compiler both so it builds on macOS and
    # with compilers that reject implicit declarations.
    mkdir -p "$root.tmp/shim"
    echo '#include <stdlib.h>' > "$root.tmp/shim/malloc.h"
    hostflags="-O2 -w -I$root.tmp/shim -include stdlib.h -include string.h -include errno.h"

    lzma_cflags=
    lzma_libs=-llzma
    if command -v pkg-config >/dev/null 2>&1 && pkg-config --exists liblzma; then
        lzma_cflags=$(pkg-config --cflags liblzma)
        lzma_libs=$(pkg-config --libs liblzma)
    elif command -v brew >/dev/null 2>&1 && xzp=$(brew --prefix xz 2>/dev/null); then
        lzma_cflags=-I$xzp/include
        lzma_libs="-L$xzp/lib -llzma"
    fi

    cross=$DEVKITPPC/bin/powerpc-eabi-
    PATH=$DEVKITPRO/tools/bin:$DEVKITPPC/bin:$PATH
    export PATH

    # shellcheck disable=SC2086
    $HOSTCC $hostflags "$src/bin2h/main.c" -o "$src/bin2h/bin2h"
    for sys in cube wii; do
        make -s -C "$src/loader/$sys" CC="${cross}gcc -m32" LD="${cross}ld" \
            OBJCOPY="${cross}objcopy"
        for high in 0 1; do
            make -s -C "$src/loader" -f "Makefile.$sys" PREFIX="$cross" high=$high clean \
                >/dev/null
            make -s -C "$src/loader" -f "Makefile.$sys" PREFIX="$cross" high=$high
        done
    done
    # shellcheck disable=SC2086
    $HOSTCC $hostflags $lzma_cflags "$src/main.c" -o "$root.tmp/dolxz" $lzma_libs
    cp "$src/LICENSE" "$root.tmp/LICENSE"
    rm -rf "$root"
    mv "$root.tmp" "$root"
}

if [ ! -x "$tool" ]; then
    echo "dolxz: building $DOLXZ_COMMIT in $root"
    build_dolxz
fi

mkdir -p "$(dirname "$out")"
"$tool" "$in" "$out" -wii "$@"
