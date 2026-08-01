#include <gctypes.h>
#include <string.h>
#include <tuxedo/ppc/intrinsics.h>

#include "framebuffer/wii_compat.h"
#include "utils/errors.h"
#include "utils/file.h"

/* Compatibility with the rw-r-r-0644 mbedTLS 3.6.4 package. */
u64 gettime(void);

u64 gettime(void)
{
	return PPCGetTickCount();
}

static nserror wii_nsurl_to_path(struct nsurl *url, char **path_out)
{
	nserror err = default_file_table->nsurl_to_path(url, path_out);

	if (err == NSERROR_OK && (*path_out)[0] == '/' &&
			(strncmp(*path_out + 1, "sd:/", 4) == 0 ||
			 strncmp(*path_out + 1, "usb:/", 5) == 0)) {
		memmove(*path_out, *path_out + 1, strlen(*path_out));
	}

	return err;
}

struct gui_file_table *wii_get_file_table(void)
{
	static struct gui_file_table file_table;

	file_table = *default_file_table;
	file_table.nsurl_to_path = wii_nsurl_to_path;
	return &file_table;
}
