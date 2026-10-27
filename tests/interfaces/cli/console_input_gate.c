#define _GNU_SOURCE
/* Linux-only PTY schedule control. The real poll, read and application signal
 * handler still run; inherited pipes hold one ready read until the parent has
 * flushed input and, when requested, observed completion of the real handler.
 * It is loaded only by proof child processes, never installed with Transit. */
#include <dlfcn.h>
#include <errno.h>
#include <poll.h>
#include <signal.h>
#include <stdatomic.h>
#include <stdlib.h>
#include <sys/syscall.h>
#include <unistd.h>

static int notify_fd = -1;
static int release_fd = -1;
static const char *marker;
static _Atomic int armed;
static _Atomic int readable;
static void (*inner[2])(int);
_Static_assert(ATOMIC_INT_LOCK_FREE == 2, "signal acknowledgment must not lock");

__attribute__((constructor)) static void configure(void) {
    const char *notify = getenv("TRANSIT_TEST_NOTIFY_FD");
    const char *release = getenv("TRANSIT_TEST_RELEASE_FD");
    marker = getenv("TRANSIT_TEST_READ_MARKER");
    if (notify && release && marker) {
        notify_fd = atoi(notify);
        release_fd = atoi(release);
    }
}
static void signal_wrapper(int signal) {
    int saved = errno;
    inner[signal == SIGTERM](signal);
    if (atomic_load(&armed)) syscall(SYS_write, notify_fd, "s", 1);
    errno = saved;
}
int sigaction(int signal, const struct sigaction *action, struct sigaction *old) {
    static int (*next)(int, const struct sigaction *, struct sigaction *);
    if (!next) next = dlsym(RTLD_NEXT, "sigaction");
    if ((signal == SIGINT || signal == SIGTERM) && action && !(action->sa_flags & SA_SIGINFO) && action->sa_handler != SIG_DFL && action->sa_handler != SIG_IGN) {
        struct sigaction wrapped = *action;
        inner[signal == SIGTERM] = action->sa_handler;
        wrapped.sa_handler = signal_wrapper;
        return next(signal, &wrapped, old);
    }
    return next(signal, action, old);
}
int poll(struct pollfd *fds, nfds_t count, int timeout) {
    int result = syscall(SYS_poll, fds, count, timeout);
    if (result > 0 && marker && access(marker, F_OK) == 0) {
        for (nfds_t i = 0; i < count; ++i) {
            if (fds[i].fd == 0 && (fds[i].revents & POLLIN)) atomic_store(&readable, 1);
        }
    }
    return result;
}
ssize_t read(int fd, void *buffer, size_t size) {
    int expected = 0;
    int held = fd == 0 && notify_fd >= 0 && atomic_load(&readable) && atomic_compare_exchange_strong(&armed, &expected, 1);
    if (held) {
        if (syscall(SYS_write, notify_fd, "r", 1) != 1) _exit(91);
        char release;
        ssize_t count;
        do { count = syscall(SYS_read, release_fd, &release, 1); } while (count < 0 && errno == EINTR);
        if (count != 1 || release != 'g') _exit(92);
    }
    ssize_t count = syscall(SYS_read, fd, buffer, size);
    int saved = errno;
    if (held && count == 0 && syscall(SYS_write, notify_fd, "z", 1) != 1) _exit(93);
    errno = saved;
    return count;
}
