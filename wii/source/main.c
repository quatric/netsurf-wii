#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

#include <curl/curl.h>
#include <fat.h>
#include <gccore.h>
#include <wiisocket.h>
#include <wiiuse/wpad.h>

#include <libnsfb.h>
#include <libnsfb_event.h>
#include <libnsfb_plot.h>

#define SCREEN_WIDTH 640
#define SCREEN_HEIGHT 480
#define CA_BUNDLE_PATH "sd:/apps/netsurf/cacert.pem"

/* The devkitPro SDL event pump calls these application hooks when the Wii's
 * power/reset controls request shutdown. */
bool TerminateRequested = false;

void Terminate(void)
{
	TerminateRequested = true;
}

static nsfb_colour_t rgb(unsigned int red, unsigned int green,
		unsigned int blue)
{
	return 0xff000000u | (blue << 16) | (green << 8) | red;
}

static void draw_scene(nsfb_t *fb, int pointer_x, int pointer_y,
		bool network_ready, bool https_ready)
{
	nsfb_bbox_t address_bar = { 18, 18, SCREEN_WIDTH - 18, 64 };
	nsfb_bbox_t content = { 18, 82, SCREEN_WIDTH - 18, SCREEN_HEIGHT - 30 };
	nsfb_bbox_t link = { 48, 132, 390, 170 };
	nsfb_bbox_t cursor_h = { pointer_x - 9, pointer_y, pointer_x + 10,
		pointer_y + 1 };
	nsfb_bbox_t cursor_v = { pointer_x, pointer_y - 9, pointer_x + 1,
		pointer_y + 10 };
	nsfb_bbox_t update = { 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT };

	nsfb_plot_clg(fb, rgb(31, 36, 48));
	nsfb_plot_rectangle_fill(fb, &address_bar, rgb(246, 247, 251));
	nsfb_plot_rectangle(fb, &address_bar, 2, rgb(82, 145, 239), false, false);
	nsfb_plot_rectangle_fill(fb, &content, rgb(255, 255, 255));
	nsfb_plot_rectangle_fill(fb, &link, rgb(224, 235, 252));
	nsfb_plot_rectangle(fb, &link, 1, rgb(47, 103, 185), false, false);

	/* The two lamps report socket and verified HTTPS readiness. */
	nsfb_plot_ellipse_fill(fb, &(nsfb_bbox_t){
		SCREEN_WIDTH - 70, 30, SCREEN_WIDTH - 52, 48
	}, network_ready ? rgb(55, 190, 105) : rgb(220, 74, 74));
	nsfb_plot_ellipse_fill(fb, &(nsfb_bbox_t){
		SCREEN_WIDTH - 46, 30, SCREEN_WIDTH - 28, 48
	}, https_ready ? rgb(55, 190, 105) : rgb(220, 74, 74));

	nsfb_plot_rectangle_fill(fb, &cursor_h, rgb(20, 20, 20));
	nsfb_plot_rectangle_fill(fb, &cursor_v, rgb(20, 20, 20));
	nsfb_update(fb, &update);
}

static bool initialise_network(void)
{
	return wiisocket_init() == 0;
}

static size_t discard_response(char *data, size_t size, size_t count,
		void *context)
{
	(void)data;
	(void)context;
	return size * count;
}

static bool probe_https(void)
{
	CURL *curl;
	CURLcode result;

	if (access(CA_BUNDLE_PATH, R_OK) != 0)
		return false;
	curl = curl_easy_init();
	if (curl == NULL)
		return false;
	curl_easy_setopt(curl, CURLOPT_URL, "https://example.com/");
	curl_easy_setopt(curl, CURLOPT_CAINFO, CA_BUNDLE_PATH);
	curl_easy_setopt(curl, CURLOPT_NOBODY, 1L);
	curl_easy_setopt(curl, CURLOPT_CONNECTTIMEOUT, 10L);
	curl_easy_setopt(curl, CURLOPT_TIMEOUT, 15L);
	curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, discard_response);
	result = curl_easy_perform(curl);
	curl_easy_cleanup(curl);
	return result == CURLE_OK;
}

int main(int argc, char **argv)
{
	nsfb_t *fb;
	int pointer_x = SCREEN_WIDTH / 2;
	int pointer_y = SCREEN_HEIGHT / 2;
	bool network_ready;
	bool https_ready = false;
	bool running = true;

	(void)argc;
	(void)argv;

	WPAD_Init();
	WPAD_SetDataFormat(WPAD_CHAN_0, WPAD_FMT_BTNS_ACC_IR);
	WPAD_SetVRes(WPAD_CHAN_0, SCREEN_WIDTH, SCREEN_HEIGHT);

	fatInitDefault();
	curl_global_init(CURL_GLOBAL_DEFAULT);
	network_ready = initialise_network();
	if (network_ready)
		https_ready = probe_https();
	fb = nsfb_new(NSFB_SURFACE_SDL);
	if (fb == NULL ||
			nsfb_set_geometry(fb, SCREEN_WIDTH, SCREEN_HEIGHT,
				NSFB_FMT_XRGB8888) != 0 ||
			nsfb_init(fb) != 0) {
		fprintf(stderr, "Unable to initialise the NetSurf framebuffer\n");
		return EXIT_FAILURE;
	}

	while (running && !TerminateRequested) {
		u32 held;
		ir_t ir;

		WPAD_ScanPads();
		held = WPAD_ButtonsHeld(WPAD_CHAN_0);
		WPAD_IR(WPAD_CHAN_0, &ir);
		if (ir.valid) {
			pointer_x = (int)ir.x;
			pointer_y = (int)ir.y;
		} else {
			if (held & WPAD_BUTTON_LEFT) pointer_x -= 4;
			if (held & WPAD_BUTTON_RIGHT) pointer_x += 4;
			if (held & WPAD_BUTTON_UP) pointer_y -= 4;
			if (held & WPAD_BUTTON_DOWN) pointer_y += 4;
		}
		if (pointer_x < 0) pointer_x = 0;
		if (pointer_x >= SCREEN_WIDTH) pointer_x = SCREEN_WIDTH - 1;
		if (pointer_y < 0) pointer_y = 0;
		if (pointer_y >= SCREEN_HEIGHT) pointer_y = SCREEN_HEIGHT - 1;

		if (WPAD_ButtonsDown(WPAD_CHAN_0) & WPAD_BUTTON_HOME)
			running = false;

		draw_scene(fb, pointer_x, pointer_y, network_ready, https_ready);
		VIDEO_WaitVSync();
	}

	nsfb_free(fb);
	curl_global_cleanup();
	wiisocket_deinit();
	return EXIT_SUCCESS;
}
