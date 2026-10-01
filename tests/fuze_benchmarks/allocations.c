/* Linux/glibc instrumentation for the external comparator, never a Transit
 * runtime dependency. Counts successful process allocation requests, including
 * Python/foreign glue; does not retain pointers or attempt live-size tracking. */
#include <stdint.h>
#include <stddef.h>
#include <stdatomic.h>
#include <errno.h>

extern void *__libc_malloc(size_t);
extern void *__libc_calloc(size_t, size_t);
extern void *__libc_realloc(void *, size_t);
extern void *__libc_memalign(size_t, size_t);

static _Atomic uint64_t requests;
static _Atomic uint64_t bytes;
static _Atomic uint64_t reallocations;

static void record(void *pointer, size_t size) {
    if (pointer) {
        atomic_fetch_add_explicit(&requests, 1, memory_order_relaxed);
        atomic_fetch_add_explicit(&bytes, size, memory_order_relaxed);
    }
}
void *malloc(size_t size) {
    void *p = __libc_malloc(size); record(p, size); return p;
}
void *calloc(size_t count, size_t size) {
    void *p = __libc_calloc(count, size); record(p, count * size); return p;
}
void *realloc(void *old, size_t size) {
    void *p = __libc_realloc(old, size);
    if (p) atomic_fetch_add_explicit(&reallocations, 1, memory_order_relaxed);
    record(p, size); return p;
}
void *memalign(size_t alignment, size_t size) {
    void *p = __libc_memalign(alignment, size); record(p, size); return p;
}
void *aligned_alloc(size_t alignment, size_t size) {
    return memalign(alignment, size);
}
int posix_memalign(void **out, size_t alignment, size_t size) {
    if (alignment < sizeof(void *) || (alignment & (alignment - 1))) return EINVAL;
    int saved_errno = errno;
    void *p = memalign(alignment, size);
    errno = saved_errno;
    if (!p) return ENOMEM;
    *out = p; return 0;
}
/* Samples need no allocation, lock, callback, storage or unbounded metadata. */
void transit_benchmark_allocations(uint64_t out[3]) {
    out[0] = atomic_load_explicit(&requests, memory_order_relaxed);
    out[1] = atomic_load_explicit(&bytes, memory_order_relaxed);
    out[2] = atomic_load_explicit(&reallocations, memory_order_relaxed);
}
