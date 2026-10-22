/* Translate the platform ABI; clock policy and implementation remain Zig. */
#include <sys/timex.h>
#include <stddef.h>
/* timex contains padding bitfields that translate-c intentionally makes opaque. */
enum {
    transit_timex_size = sizeof(struct timex),
    transit_timex_align = _Alignof(struct timex),
    transit_timex_status = offsetof(struct timex, status),
    transit_timex_maxerror = offsetof(struct timex, maxerror),
    transit_timex_time = offsetof(struct timex, time)
};
