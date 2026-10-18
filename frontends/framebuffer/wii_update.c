/*
 * Update check for the Wii port, using libwiiupdate.
 *
 * The check runs in the background while NetSurf starts. Its result is
 * shown on the loading screen's status line, where A installs the new
 * release over this copy and B carries on with the browser.
 */

#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>
#include <gccore.h>
#include <wiiuse/wpad.h>
#include <input_wii.h>
#include <ogc/lwp_watchdog.h>
#include <wiiupdate.h>

#include "framebuffer/wii_loading.h"
#include "framebuffer/wii_update.h"

#define CHECK_WAIT_MS 10000
#define OFFER_WAIT_MS 20000

static bool started;

/* Every controller libinput-wii knows, folded onto Wii Remote buttons. */
static u32 buttons_down(void)
{
	INPUT_Update();
	return INPUT_ButtonsDown();
}

static int elapsed_ms(u64 since)
{
	return (int)ticks_to_millisecs(diff_ticks(since, gettime()));
}

/* Show a status line and wait for A or B, or until timeout_ms (<0: forever). */
static u32 ask(const char *status, int timeout_ms)
{
	u64 start = gettime();
	u32 down = 0;

	wii_loading_status(status, false);
	while (timeout_ms < 0 || elapsed_ms(start) < timeout_ms) {
		VIDEO_WaitVSync();
		if ((down = buttons_down() & (WPAD_BUTTON_A | WPAD_BUTTON_B)) != 0)
			break;
	}
	return down;
}

/* exported function documented in framebuffer/wii_update.h */
void wii_update_start(const char *argv0)
{
	WIIUPDATE_SetAppPath(argv0);
	started = WIIUPDATE_Start("quatric", "netsurf-wii", APP_VERSION) == 0;
}

static void install(void)
{
	char status[64];
	wiiupdate_install_state st;
	int shown = -1;

	if (WIIUPDATE_Install() < 0)
		return;
	while ((st = WIIUPDATE_InstallState()) == WIIUPDATE_INSTALL_DOWNLOADING ||
	       st == WIIUPDATE_INSTALL_EXTRACTING) {
		int pct = WIIUPDATE_Progress();

		if (pct != shown) {
			if (st == WIIUPDATE_INSTALL_DOWNLOADING)
				snprintf(status, sizeof(status), "Downloading update %d%% (B to cancel)", pct);
			else
				snprintf(status, sizeof(status), "Installing update %d%%", pct);
			wii_loading_status(status, false);
			shown = pct;
		}
		VIDEO_WaitVSync();
		if (st == WIIUPDATE_INSTALL_DOWNLOADING && (buttons_down() & WPAD_BUTTON_B))
			WIIUPDATE_Cancel();
	}
	WIIUPDATE_Wait(5000);

	if (st == WIIUPDATE_INSTALL_DONE) {
		snprintf(status, sizeof(status), "Updated to %s. A: back to the loader", WIIUPDATE_Latest());
		while (!(ask(status, -1) & WPAD_BUTTON_A))
			;
		exit(0);
	}
	snprintf(status, sizeof(status), "Update failed: %s", WIIUPDATE_InstallError());
	ask(status, 4000);
}

/* exported function documented in framebuffer/wii_update.h */
void wii_update_prompt(void)
{
	char status[64];

	if (!started)
		return;
	/* The same flags libnsfb's SDL surface uses: its own INPUT_InitEx()
	 * later is then a no-op, and it still applies its button settings. */
	INPUT_InitEx(INPUT_INIT_NO_KEYBOARD | INPUT_INIT_NO_MOUSE);

	if (WIIUPDATE_State() == WIIUPDATE_CHECKING) {
		u64 start = gettime();

		wii_loading_status("Checking for updates (B to skip)", true);
		while (WIIUPDATE_State() == WIIUPDATE_CHECKING) {
			VIDEO_WaitVSync();
			if ((buttons_down() & WPAD_BUTTON_B) || elapsed_ms(start) > CHECK_WAIT_MS) {
				WIIUPDATE_Cancel();
				return;
			}
		}
	}
	if (!WIIUPDATE_TakeNotice())
		return;

	if (!WIIUPDATE_CanInstall()) {
		snprintf(status, sizeof(status), "NetSurf %s is out: github.com/quatric/netsurf-wii",
			 WIIUPDATE_Latest());
		ask(status, 6000);
		return;
	}
	snprintf(status, sizeof(status), "NetSurf %s is out. A: Update  B: Later", WIIUPDATE_Latest());
	if (ask(status, OFFER_WAIT_MS) & WPAD_BUTTON_A)
		install();
	wii_loading_status("Starting NetSurf", true);
}
