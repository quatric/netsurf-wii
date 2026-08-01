#include <gctypes.h>
#include <tuxedo/ppc/intrinsics.h>

/* The rw-r-r-0644 mbedTLS 3.6.4 binary was built against a libogc revision
 * where gettime() had external linkage. It is static-inline in libogc 3.x, so
 * provide the one ABI symbol required by those prebuilt objects. */
u64 gettime(void);

u64 gettime(void)
{
	return PPCGetTickCount();
}
