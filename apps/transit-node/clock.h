/* Translate the platform ABI; clock policy and implementation remain Zig. */
#include <sys/timex.h>
#include <stddef.h>
/* timex contains padding bitfields that translate-c intentionally makes opaque. */
enum {
    rey_timex_size = sizeof(struct timex),
    rey_timex_align = _Alignof(struct timex),
    rey_timex_status = offsetof(struct timex, status),
    rey_timex_maxerror = offsetof(struct timex, maxerror),
    rey_timex_time = offsetof(struct timex, time)
};
