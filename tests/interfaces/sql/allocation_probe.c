/* Test-only glibc interposition. Counts attempts, including failed calls.
 * Does not claim visibility into hidden libc allocators or arbitrary syscalls;
 * the Zig owner counters and process/thread mapping observer are separate. */
#include <stdint.h>
#if defined(__linux__) && defined(__GLIBC__)
#include <errno.h>
#include <stddef.h>
#include <stdatomic.h>
#include <stdlib.h>
#include <sys/prctl.h>
extern void *__libc_malloc(size_t);
extern void *__libc_calloc(size_t, size_t);
extern void *__libc_realloc(void *, size_t);
extern void *__libc_memalign(size_t, size_t);
extern void __libc_free(void *);
static _Atomic int enabled;
static _Atomic uint64_t counts[4];
static void count(unsigned slot) {
    if (atomic_load_explicit(&enabled, memory_order_relaxed))
        atomic_fetch_add_explicit(&counts[slot], 1, memory_order_relaxed);
}
void *malloc(size_t n) { count(0); return __libc_malloc(n); }
void *calloc(size_t n, size_t size) { count(1); return __libc_calloc(n, size); }
void *realloc(void *p, size_t n) { count(2); return __libc_realloc(p, n); }
void free(void *p) { __libc_free(p); }
void *memalign(size_t alignment, size_t n) { count(3); return __libc_memalign(alignment, n); }
void *aligned_alloc(size_t alignment, size_t n) {
    count(3);
    if (!alignment || (alignment & (alignment - 1)) || n % alignment) { errno = EINVAL; return NULL; }
    return __libc_memalign(alignment, n);
}
int posix_memalign(void **p, size_t alignment, size_t n) {
    count(3);
    if (alignment < sizeof(void *) || (alignment & (alignment - 1))) return EINVAL;
    void *value = __libc_memalign(alignment, n);
    if (!value) return ENOMEM;
    *p = value;
    return 0;
}
int transit_allocation_begin(void) {
    for (unsigned i = 0; i < 4; i++) atomic_store(&counts[i], 0);
    if (prctl(PR_SET_NAME, "alloc_begin", 0, 0, 0)) return 1;
    atomic_store(&enabled, 1);
    return 0;
}
int transit_allocation_end(uint64_t out[4]) {
    atomic_store(&enabled, 0);
    for (unsigned i = 0; i < 4; i++) out[i] = atomic_load(&counts[i]);
    return prctl(PR_SET_NAME, "alloc_end", 0, 0, 0);
}
void transit_allocation_negative(void) {
    void *a = malloc(17);
    void *b = realloc(a, 2048);
    free(b ? b : a);
    free(calloc(3, 17));
    free(memalign(64, 128));
}
#else
int transit_allocation_begin(void) { return 1; }
int transit_allocation_end(uint64_t out[4]) { (void)out; return 1; }
void transit_allocation_negative(void) {}
#endif
