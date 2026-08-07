#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DOWNLOAD_DIR="$SCRIPT_DIR/.deps/downloads"
EXTRACT_DIR="$SCRIPT_DIR/.deps/network-extract"
PREFIX="$SCRIPT_DIR/.deps/network"
RELEASE_URL="https://github.com/AndrewPiroli/wii-curl/releases/download/c8.16.0%2Bm3.6.4"

mkdir -p "$DOWNLOAD_DIR" "$EXTRACT_DIR" "$PREFIX/include" "$PREFIX/lib"

download_and_check() {
	name=$1
	want=$2
	if [ ! -f "$DOWNLOAD_DIR/$name" ]; then
		curl -fL "$RELEASE_URL/$name" -o "$DOWNLOAD_DIR/$name"
	fi
	got=$(shasum -a 256 "$DOWNLOAD_DIR/$name" | awk '{print $1}')
	if [ "$got" != "$want" ]; then
		echo "Checksum mismatch for $name" >&2
		exit 1
	fi
}

download_and_check libwiisocket-0.1-1-any.pkg.tar.gz \
	a77be1d6c0e3e5adb87fb751a9fdc89b325f7f9bdee77742b903b7aba15f20cc
download_and_check wii-mbedtls-3.6.4-1-any.pkg.tar.gz \
	0b0d3eb9aa93fd26f9caf2a52f8236354861daf4c558b95e0a3f67bc66c655de
download_and_check wii-curl-8.16.0-1-any.pkg.tar.gz \
	5aa5109b0baed29e516deef074f68d01798b24df6632a45cac0a8807dbdb0404

for package in "$DOWNLOAD_DIR"/*.pkg.tar.gz; do
	tar -xzf "$package" -C "$EXTRACT_DIR"
done

cp -R "$EXTRACT_DIR/opt/devkitpro/portlibs/wii/include/." "$PREFIX/include/"
cp -R "$EXTRACT_DIR/opt/devkitpro/portlibs/wii/lib/." "$PREFIX/lib/"
cp -R "$EXTRACT_DIR/opt/devkitpro/libogc/include/." "$PREFIX/include/"
cp "$EXTRACT_DIR/opt/devkitpro/libogc/lib/wii/libwiisocket.a" "$PREFIX/lib/"

# libogc 3.x gained inet_ntop/inet_pton after this package was published.
# Remove the duplicate implementations while retaining getaddrinfo/select and
# wiisocket's devoptab integration, which curl still needs.
#
# libogc keeps all five address-string helpers in one object (soc_util.o), so
# pulling it in for inet_ntop/inet_pton drags inet_addr/inet_aton/inet_ntoa
# along with it. Those have to go from libwiisocket as well or the link fails
# with multiple definitions. They only convert between text and in_addr, so
# either implementation is equivalent -- unlike the socket calls below, they
# touch no file descriptor.
"${DEVKITPPC:-/opt/devkitpro/devkitPPC}/bin/powerpc-eabi-ar" d \
	"$PREFIX/lib/libwiisocket.a" inet_ntop.o inet_pton.o \
	inet_addr.o inet_aton.o inet_ntoa.o
"${DEVKITPPC:-/opt/devkitpro/devkitPPC}/bin/powerpc-eabi-ranlib" \
	"$PREFIX/lib/libwiisocket.a"

# The shipped libcurl.pc lists "-logc -lwiisocket" in that order. libogc 3.x
# also defines socket/connect/send/recv/poll and 14 other BSD socket entry
# points, so with -logc first the static linker satisfies libcurl's references
# from libogc's raw IOS wrappers while select()/getaddrinfo()/close() still
# come from libwiisocket and newlib's devoptab. The two do not share a file
# descriptor space, so every fetch fails to connect. Put libwiisocket first so
# it wins for all of the overlapping symbols; libogc keeps supplying
# inet_ntop/inet_pton, which are deleted from libwiisocket above.
for pc in "$PREFIX/lib/pkgconfig/libcurl.pc"; do
	sed -i.bak 's/-logc -lwiisocket/-lwiisocket -logc/g' "$pc"
	rm -f "$pc.bak"
done

CA_URL="https://raw.githubusercontent.com/AndrewPiroli/wii-curl/d9b21a24142c6bfbfff15cd4151ef154b9659c4e/sample-app/data/cacert.pem"
curl -fL "$CA_URL" -o "$SCRIPT_DIR/cacert.pem"
CA_HASH=$(shasum -a 256 "$SCRIPT_DIR/cacert.pem" | awk '{print $1}')
if [ "$CA_HASH" != \
		"189d3cf6d103185fba06d76c1af915263c6d42225481a1759e853b33ac857540" ]; then
	echo "Checksum mismatch for cacert.pem" >&2
	exit 1
fi
