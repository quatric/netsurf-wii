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
#
# Two changes against a plain build of upstream:
# - The loader stubs are built with -fno-builtin -fno-tree-loop-distribute-patterns.
#   Newer GCC (seen with devkitPPC r50, GCC 16.1) otherwise compiles the stubs' own memset
#   into a branch to itself, and the compressed .dol hangs before decompressing.
# - Section sizes in the output are rounded up to 32 bytes (the padding is zeros
#   the loader never reads). Dolphin stops at a dialog for unaligned sections.
set -eu

DOLXZ_COMMIT=bf73653618facd06c1f5c98e81215d2298aefc40
# Bump when the way dolxz is built here changes, so stale caches are rebuilt.
DOLXZ_BUILD=2

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

root=$DOLXZ_CACHE/$DOLXZ_COMMIT-$DOLXZ_BUILD
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
    nolib="-fno-builtin -fno-tree-loop-distribute-patterns"
    for sys in cube wii; do
        make -s -C "$src/loader/$sys" CC="${cross}gcc -m32" LD="${cross}ld" \
            OBJCOPY="${cross}objcopy" \
            CFLAGS="-Wall -W -O2 -ffreestanding $nolib -mno-eabi -mno-sdata -mcpu=750"
        for high in 0 1; do
            make -s -C "$src/loader" -f "Makefile.$sys" PREFIX="$cross" high=$high clean \
                >/dev/null
            make -s -C "$src/loader" -f "Makefile.$sys" PREFIX="$cross" high=$high \
                CFLAGS="\$(MACHDEP) -O2 -Wall $nolib"
        done
    done
    # shellcheck disable=SC2086
    $HOSTCC $hostflags $lzma_cflags "$src/main.c" -o "$root.tmp/dolxz" $lzma_libs
    cat > "$root.tmp/dolpad.c" <<'PADEOF'
/* Round each DOL section size up to 32 bytes where the file layout leaves room. */
#include <stdio.h>
#include <stdlib.h>

static unsigned int rd(const unsigned char *p)
{
    return (unsigned int)p[0] << 24 | (unsigned int)p[1] << 16 | (unsigned int)p[2] << 8 | p[3];
}

static void wr(unsigned char *p, unsigned int v)
{
    p[0] = v >> 24;
    p[1] = v >> 16;
    p[2] = v >> 8;
    p[3] = v;
}

int main(int argc, char **argv)
{
    unsigned char h[0x100];
    unsigned int end = 0;
    long size;
    int i, j;
    FILE *f;

    if (argc != 2 || !(f = fopen(argv[1], "r+b")) || fread(h, 1, sizeof h, f) != sizeof h)
        return 1;
    fseek(f, 0, SEEK_END);
    size = ftell(f);
    for (i = 0; i < 18; i++)
    {
        unsigned int off = rd(h + i * 4), len = rd(h + 0x90 + i * 4);
        unsigned int padded = (len + 31) & ~31u, next = 0xffffffffu;
        if (!len)
            continue;
        for (j = 0; j < 18; j++)
        {
            unsigned int o = rd(h + j * 4);
            if (j != i && rd(h + 0x90 + j * 4) && o > off && o < next)
                next = o;
        }
        if (off + padded <= next)
            wr(h + 0x90 + i * 4, len = padded);
        if (off + len > end)
            end = off + len;
    }
    fseek(f, 0, SEEK_SET);
    fwrite(h, 1, sizeof h, f);
    for (fseek(f, 0, SEEK_END); (unsigned long)size < end; size++)
        fputc(0, f);
    return fclose(f) != 0;
}
PADEOF
    $HOSTCC -O2 "$root.tmp/dolpad.c" -o "$root.tmp/dolpad"
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
"$root/dolpad" "$out"
