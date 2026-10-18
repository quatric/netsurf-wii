#ifndef NETSURF_FRAMEBUFFER_WII_UPDATE_H
#define NETSURF_FRAMEBUFFER_WII_UPDATE_H

/**
 * Start checking GitHub for a newer release, once the network is up.
 *
 * \param argv0 argv[0] as passed to main, so an update lands in the
 *              folder NetSurf was started from.
 */
void wii_update_start(const char *argv0);

/**
 * Before the browser takes over the screen: finish the check (B skips it)
 * and, when a newer release is out, offer it on the loading screen's status
 * line. Does not return if the update was installed and the user chose to
 * go back to the loader.
 */
void wii_update_prompt(void);

#endif
