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
  function keys, and modifier keys work normally, and held keys repeat.
  Characters follow the layout libogc picks from the Wii's system language, or
  from a `wiikbd.map` file at the root of the SD card. Ctrl+P writes the
  current page to `sd:/apps/netsurf/netsurf.pdf`.
- USB mouse: relative motion moves the browser pointer; left, middle, and
  right buttons map to the corresponding browser buttons; the wheel scrolls.
- Wii Remote: aim with IR; A and B are left and right click. The D-pad sends
  arrow keys, 1 and 2 are Page Up and Page Down, Plus and Minus zoom in and
  out, and Home exits. A Nunchuk's stick scrolls.
- Classic Controller, GameCube controller and Wii U Pro Controller: the left
  (main) stick moves the pointer and the right stick (C-stick) scrolls. A and B
  click, X and Y are Page Down and Page Up, Plus/Minus, ZR/ZL or R/L zoom, the
  D-pad sends arrow keys, and Home (Start on a GameCube controller) exits.

Clicking the URL bar or a text field on a page opens the on-screen keyboard,
which the keyboard button at the bottom right also opens. For page fields it
opens when the click is released, so clicking a field again after hiding the
keyboard brings it back. While it is open the browser window shrinks to sit
above it, and the page scrolls the field into view. Shift applies to the next
key only; Caps Lock stays on and affects letters only, and Shift reverses it.
Both also follow a USB keyboard's Shift and Caps Lock.
Enter and Hide close the keyboard, and it also closes whenever a page starts
loading, for example after a search or a link. The toolbar's Home button
returns to the welcome page, whose bookmarks include
[The Old Net](http://theoldnet.com/), an archive of 1990s and 2000s websites
served for older browsers.

While NetSurf starts it shows `loading.png` with a status line in Bree Serif
(`fonts/BreeSerif-Regular.ttf`, under the SIL Open Font License in
`fonts/BreeSerif-OFL.txt`). Until SDL sets its video mode the screen is drawn
straight into the frame buffer on display, and afterwards into SDL's screen
surface. SDL-wii blanks the screen twice on the way: starting its video
subsystem replaces the frame buffer, so that is done before the loading
screen is first drawn, and setting the video mode copies a black frame, so
the loading screen is shown from a second frame buffer until SDL's own
buffer has it. If networking fails, the error stays on
screen for three seconds before the browser starts. Outside the TV-safe
margin the screen is light blue (#94aeff) rather than black. The loading
screen and Homebrew Channel icon are adapted from NetSurf's own logo
artwork, which `COPYING` licenses under the MIT License.

A standard definition TV signal blurs fine detail, so the package ships a
`user.css` that gives text fields 2px black borders and a little extra
spacing. It is a user style sheet, so it only applies where a page does not
style its own fields.

USB HID support targets boot-protocol keyboards and mice. It is experimental;
there is no compatibility guarantee or end-user support for particular USB
devices.

### Wii Remote troubleshooting

The Wii Remote cursor requires a visible Sensor Bar. Aim the Remote at the
screen, keep the bar within its field of view, and remain within the usual
Bluetooth range. If the cursor disappears, point the Remote at the Sensor Bar
again; without IR the pointer cannot be aimed, but a Classic Controller,
GameCube controller or Wii U Pro Controller stick can still move it. Slow page
loading is separate from pointer movement and is expected on complex modern
sites.

When testing in Dolphin, install the complete `apps/netsurf` directory into
Dolphin's emulated SD card. Opening `boot.dol` directly does not make sibling
host files visible as `sd:/apps/netsurf`, so the browser will start without
its Messages, CSS, or welcome page. Runtime progress is written to Dolphin's
OSReport log under the `NetSurf Wii:` prefix.

Set Dolphin's texture cache accuracy to Safe (Graphics > Advanced, or
`SafeTextureCacheColorSamples = 0` in `GFX.ini`). SDL-wii presents the whole
screen as one GX texture, and the faster settings only sample it for changes,
so pointer movement and other small updates can appear frozen until something
larger redraws. The USB keyboard and mouse path has not been exercised in
Dolphin and needs testing on real hardware.

## Prerequisites

- devkitPro with `wii-dev`
- `wii-sdl`, `ppc-zlib`, `ppc-libpng`, `ppc-libjpeg-turbo`, `ppc-libwebp`,
  and `ppc-freetype`
- Git, GNU Make, GNU flex, and a recent GNU bison
- Licensed `FOT-RodinNTLGPro-DB.otf` and `FOT-RodinNTLGPro-B.otf` files in
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
under `wii/.deps/input/prefix` by `bootstrap-input.sh`, together with a pinned
[libinput-wii](https://github.com/quatric/libinput-wii) built against it.
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
  synthesise those a second time: it starts libinput-wii with
  `INPUT_IgnoreWiimoteButtons(0, A | B)`. Its `INPUT_Update()` calls
  `WPAD_ScanPads()`, which is what keeps SDL's handling supplied with fresh
  data, and the patch rate limits every hardware poll to 16 ms. Remotes two to
  four contribute their buttons through libinput-wii. libinput-wii's
  initialisation repeats what SDL-wii's `main()` already did (IR data format
  and a 640x480 range on every channel) before `SDL_SetVideoMode()` widens
  channel zero's range, so it must keep the IR format (no
  `INPUT_INIT_NO_POINTER`) and the patch must never call
  `INPUT_SetScreenSize()`. The patch must not call `WPAD_SetVRes()`:
  SDL-wii gives channel zero an IR range 1.25 times the screen and subtracts
  that margin itself, so a 640x480 range left the pointer unable to pass
  x=552 or y=398, which put the on-screen keyboard's bottom row out of reach.
- malloc moves on from MEM1 into the larger MEM2 arena once MEM1 runs out.
  This is libogc's default; `MALLOC_MEM2` in
  `frontends/framebuffer/wii_compat.c` only restates it. MEM2 has higher
  latency than MEM1, but NetSurf's working set does not fit in MEM1 alone.
- SDL-wii's `UpdateRects` wakes its presentation thread without that
  thread's lock, so an update made while it was drawing stayed off screen
  until the next one, which left stale strips after scrolling. The `libnsfb`
  patch collects a redraw pass's updates and sends them together when NetSurf
  next asks for input, then wakes the thread again for a few frames.
- Decoded images are stored as native 0xAABBGGRR words
  (`bitmap_set_format()` in `gui.c`), which is what libnsfb reads, so plotting
  needs no per-frame copy or byte swapping. The compiled-in toolbar icons and
  pointers are generated in the same format by `tools/convert_image.c`.
- The framebuffer is 640x480x32, or 848x480x32 when the Wii is set to 16:9
  (`wii_screen_width()`): SDL-wii squeezes that mode into the TV signal and a
  widescreen TV stretches it back, so pages keep their shape and gain width.
  The loading screen is centered across the wider mode with its edge colors
  carried out to the sides, and the on-screen keyboard keeps its 4:3 height.
  Dropping to 16bpp would halve both the plot and the GX texture conversion
  bandwidth, but NetSurf's 16bpp plotters and SDL-wii's 16bpp path are
  untested here.
- SDL-wii's event pump would also drain libogc's destructive USB HID queues,
  so each report reached only one of the two readers. The browser links with
  `--wrap` for `KEYBOARD_GetEvent` and `MOUSE_GetEvent`: SDL-wii always finds
  the queues empty and the `libnsfb` patch is the only reader. The patch passes
  libogc's layout-aware characters on as `NSFB_KEY_CHARACTER` plus the
  character, a key code range the patch adds to `libnsfb_event.h`, so the
  framebuffer frontend's own (UK) shift table does not shift them again. The
  on-screen keyboard sends its characters the same way, and its labels follow
  a USB keyboard's Shift and Caps Lock.
- libogc's USB mouse driver turns the wheel off for good the first time a
  report carries a wheel step other than -1, 0 or 1, which a fast flick can
  do; unplugging and reconnecting the mouse brings it back. This is in
  `libogc/usbmouse.c` (`_mouse_event_cb`) and is best fixed there.
- Controllers (Wii Remotes two to four, Nunchuk, Classic Controller, GameCube
  pads, and Wii U Pro Controllers through libwupc) are read through
  libinput-wii, which merges every device into one button mask; their mapping
  is listed under Controls. The USB keyboard and mouse stay on libogc's
  drivers, which SDL-wii's `main()` starts: the keyboard driver applies the
  keyboard layout, and libinput-wii is started without its own keyboard and
  mouse so the devices have one reader each. Sticks use
  `INPUT_StickRaw()` scaled back to the divisors the patch always used
  (GameCube 80, Wii U Pro 1024); the strongest stick on each side wins.
- WebP image decoding is enabled; JPEG XL is excluded to keep the browser and
  its dependency set smaller. PDF export uses libharu and a fixed output path;
  a Wii-native filename picker has not been implemented.
- JavaScript remains available through the bundled Duktape engine when enabled
  in `Choices`; `js-smoke.html` is a target-side JavaScript/DOM diagnostic.
  Modern sites can still exceed the Wii's memory or depend on browser APIs
  NetSurf does not implement.
- Cookies and the CA bundle are redirected to `sd:/apps/netsurf/`; downloads
  and user choices still need Wii-specific defaults and runtime testing.
- NetSurf waits for network startup before showing the UI, so the first
  fetches do not race DHCP. If networking fails it logs the error and starts
  anyway; local pages still work.

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
