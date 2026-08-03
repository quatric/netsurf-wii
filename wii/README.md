# NetSurf on Wii

Wii port maintained by quatric <quatricsoftware@gmail.com>.

This is an experimental port of the complete NetSurf framebuffer browser to
the Nintendo Wii. It cross-compiles NetSurf and its support libraries for
PowerPC/Gekko, uses SDL 1.2 and libnsfb for display, and uses the Wii curl and
mbedTLS packages maintained by rw-r-r-0644 for HTTPS.

The resulting application is under `wii/dist/apps/netsurf/`. Copy that whole
directory to `sd:/apps/netsurf/` and start it from the Homebrew Channel. The
CA bundle, Messages catalogue, CSS, and built-in pages must remain beside
`boot.dol`. With a USB keyboard, Ctrl+P exports the current page to
`sd:/apps/netsurf/netsurf.pdf`. Open
`file:///sd:/apps/netsurf/js-smoke.html` for a small JavaScript/DOM diagnostic
page.

## Controls

Connect a standard USB HID keyboard or mouse to either Wii USB port (a powered
hub is recommended when the SD/USB storage device is also in use). Devices are
hot-plugged, so they may be connected before or after NetSurf starts.

- USB keyboard: text entry, browser shortcuts, arrows, Home/End, Page Up/Down,
  function keys, and modifier keys work normally. Ctrl+P writes the current
  page to `sd:/apps/netsurf/netsurf.pdf`.
- USB mouse: relative motion moves the browser pointer; left, middle, and
  right buttons map to the corresponding browser buttons; the wheel scrolls.
- Wii Remote: aim with IR; A and B are left and right click. Without IR, use
  the D-pad to move the pointer. Home exits.

USB HID support targets boot-protocol keyboards and mice. It is experimental;
there is no compatibility guarantee or end-user support for particular USB
devices.

### Wii Remote troubleshooting

The Wii Remote cursor requires a visible Sensor Bar. Aim the Remote at the
screen, keep the bar within its field of view, and remain within the usual
Bluetooth range. If the cursor disappears, point the Remote at the Sensor Bar
again; the D-pad remains available as a fallback while IR is unavailable.
D-pad movement is intentionally slower than IR and is best used only to
recover the pointer or make small adjustments. Slow page loading is separate
from pointer movement and is expected on complex modern sites.

When testing in Dolphin, install the complete `apps/netsurf` directory into
Dolphin's emulated SD card. Opening `boot.dol` directly does not make sibling
host files visible as `sd:/apps/netsurf`, so the browser will start without
its Messages, CSS, or welcome page. Runtime progress is written to Dolphin's
OSReport log under the `NetSurf Wii:` prefix.

## Prerequisites

- devkitPro with `wii-dev`
- `wii-sdl`, `ppc-zlib`, `ppc-libpng`, `ppc-libjpeg-turbo`, `ppc-libwebp`,
  and `ppc-freetype`
- Git, GNU Make, GNU flex, and a recent GNU bison
- Licensed `FOT-RodinNTLGPro-M.otf` and `FOT-RodinNTLGPro-B.otf` files in
  `~/Library/Fonts`, or another directory selected with `RODIN_FONT_DIR`

## Build

```sh
cd /path/to/netsurf-wii
./wii/bootstrap-network.sh
./wii/bootstrap-browser-deps.sh
./wii/build-browser.sh -j8
```

`build-browser.sh` uses cross-built NetSurf support libraries under
`wii/.deps/netsurf-workspace/inst-powerpc-eabi` and GNU libiconv under
`wii/.deps/iconv`. WebP comes from devkitPro, while libharu 2.4.6 is
cross-built under `wii/.deps/optional/prefix`.
The pinned FIX94 libwupc source is adapted to current libogc and installed
under `wii/.deps/input/prefix` by `bootstrap-input.sh`.
`bootstrap-browser-deps.sh` creates the local prefixes. They are intentionally
untracked. The
rw-r-r-0644 packages are also extracted locally because installing the older
libwiisocket package globally conflicts with socket headers now supplied by
current libogc.

The build copies FOT-Rodin NTLG Pro into the ignored application package at
`apps/netsurf/fonts`; the licensed source fonts are not copied into the source
tree. The framebuffer frontend does not currently consume downloaded CSS
webfonts, so Rodin is used for generic and named page font requests.

`RODIN_REGULAR_SOURCE` and `RODIN_BOLD_SOURCE` can override the two input font
paths. The GitHub Actions build uses those overrides with DejaVu solely to
produce a redistributable CI test package; local builds continue to use the
licensed FOT-Rodin NTLG Pro faces by default.

## Continuous integration

`.github/workflows/wii-build.yaml` builds in the pinned official devkitPPC
container on pushes, pull requests, and manual dispatches. It bootstraps every
Wii dependency, verifies the DOL and package metadata, audits build provenance,
and uploads a checksummed `netsurf-wii-ci.tar.gz` artifact for 14 days.

Release publishing is intentionally not part of the build workflow. Releases
for `quatric/netsurf-wii` must be started separately and only after an explicit
approval to publish.

For a quick hardware/display/network diagnostic independent of the full
browser, `./wii/bootstrap-deps.sh && make -C wii package` builds the small
`netsurf-wii-smoke` application.

## Port architecture

```text
NetSurf core -> framebuffer frontend -> libnsfb -> SDL 1.2 -> libogc/GX
NetSurf fetcher -> libcurl -> libogc BSD sockets -> Wii network interface
```

## Current limitations

- This build has not yet been tested on physical Wii hardware.
- The Wii low-memory profile reserves memory for rendering: the in-memory cache
  is capped at 6 MiB, disk cache at 16 MiB, font cache at 512 KiB, and no
  decoded bitmap may exceed 4 MiB or 2048 pixels on either side. Oversized
  images fail to load instead of exhausting MEM2.
- JavaScript, background images, and image animation are disabled by default.
  The browser also limits itself to four active fetches (two per host) and
  blocks advertisements by default. Users may override these defaults in
  `sd:/apps/netsurf/Choices`, but doing so can reduce stability.
- USB keyboard and mouse input uses libogc's boot-protocol HID drivers. It is
  intended for ordinary wired devices; wireless receivers and composite HID
  devices need hardware testing and are not supported on request.
- Wii Remote channel zero's IR pointer and its A and B buttons are handled by
  SDL-wii's own event pump, which already emits absolute mouse motion and left
  and right mouse buttons for them. The `libnsfb` patch deliberately does not
  synthesise those a second time. It does call `WPAD_ScanPads()`, because that
  is what keeps SDL's handling supplied with fresh data, and it rate limits
  every hardware poll to 16 ms. Remotes two to four contribute their buttons
  through the patch's own path.
- malloc is routed at libogc's MEM2 arena (`MALLOC_MEM2` in
  `frontends/framebuffer/wii_compat.c`). Without it libogc serves every
  allocation from arena 1 in MEM1, which the executable, SDL's surfaces and the
  GX FIFO have already largely consumed, and the low-memory profile's budgets
  cannot be met. MEM2 has higher latency than MEM1, so this trades some speed
  for roughly 50 MiB of usable heap.
- The framebuffer is 640x480x32. Dropping to 16bpp would halve both the plot
  and the GX texture conversion bandwidth, but NetSurf's 16bpp plotters and
  SDL-wii's 16bpp path are untested here.
- Both the `libnsfb` patch and SDL-wii's event pump drain libogc's USB HID
  queues with `KEYBOARD_GetEvent()` and `MOUSE_GetEvent()`. Reads are
  destructive, so the two paths race for each report and a given keystroke
  reaches NetSurf through whichever won. This needs resolving in favour of one
  path; it has not been done.
- Wii U Pro Controllers are detected through libwupc before SDL initializes
  WPAD. GlowWii-style four-channel aggregation gives them precedence over
  GameCube pads. A/B click, the D-pad sends arrows, Plus/Minus send `+`/`-`,
  X/Y send Page Down/Page Up, and Home sends Escape.
- WebP image decoding is enabled; JPEG XL is excluded to keep the browser and
  its dependency set smaller. PDF export uses libharu and a fixed output path;
  a Wii-native filename picker has not been implemented.
- JavaScript remains available through the bundled Duktape engine when enabled
  in `Choices`; `js-smoke.html` is a target-side JavaScript/DOM diagnostic.
  Modern sites can still exceed the Wii's memory or depend on browser APIs
  NetSurf does not implement.
- Cookies and the CA bundle are redirected to `sd:/apps/netsurf/`; downloads
  and user choices still need Wii-specific defaults and runtime testing.
- Network startup is asynchronous so a missing Dolphin network configuration
  does not prevent the UI from appearing. The initial page is local; network
  requests made before socket startup completes can fail and may need reload.

The small `libnsfb` patch adds devkitPPC/newlib endian detection and Wii input
polling. It is kept separate so it can be proposed upstream.
`bootstrap-browser-deps.sh` only applies it when it is not already applied, so
after editing `wii/.deps/netsurf-workspace/libnsfb` regenerate the patch with
`git -C wii/.deps/netsurf-workspace/libnsfb diff > wii/patches/libnsfb-wii-endian.patch`.

## Support

This is experimental hobby software. No end-user support or device-compatibility
guarantee is provided. Project correspondence: quatric
<quatricsoftware@gmail.com>.

Copyright (c) 2026 quatric
