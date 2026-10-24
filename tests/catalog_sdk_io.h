#ifndef TRANSIT_TEST_CATALOG_IO_H
#define TRANSIT_TEST_CATALOG_IO_H
#ifndef _POSIX_C_SOURCE
#define _POSIX_C_SOURCE 200809L
#endif
#include <transit/catalog.h>
#include <assert.h>
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>
static char line[256];
static char *args[3];
static inline int read_command(void) {
    if (!fgets(line, sizeof(line), stdin)) return 0;
    assert(strchr(line, '\n')); size_t n = 0;
    for (char *p = strtok(line, " \n"); p; p = strtok(NULL, " \n")) { assert(n < 3); args[n++] = p; }
    assert(n); for (; n < 3; ++n) args[n] = NULL; return 1;
}
static inline uint64_t number(const char *v) {
    assert(v && *v && *v != '-'); errno = 0; char *end = NULL;
    unsigned long long n = strtoull(v, &end, 10); assert(!errno && !*end); return (uint64_t)n;
}
static inline void checked(transit_sdk_error e) {
    if (e.kind) { fprintf(stderr, "catalog kind=%d status=%u phase=%s code=%s\n", e.kind, e.native_status, e.phase, e.code); abort(); }
}
static inline double now(void) { struct timespec t; assert(!clock_gettime(CLOCK_MONOTONIC, &t)); return (double)t.tv_sec + (double)t.tv_nsec / 1e9; }
static inline void persist(const char *root, const char *name, transit_sdk_bytes value) {
    char path[4096], temporary[4096]; assert(snprintf(path, sizeof(path), "%s/%s", root, name) < (int)sizeof(path));
    assert(snprintf(temporary, sizeof(temporary), "%s/%s.tmp", root, name) < (int)sizeof(temporary));
    int fd = open(temporary, O_WRONLY | O_CREAT | O_TRUNC | O_NOFOLLOW, 0600); assert(fd >= 0);
    size_t offset = 0; while (offset < value.size) { ssize_t n = write(fd, value.data + offset, value.size - offset); assert(n > 0); offset += (size_t)n; }
    assert(!fsync(fd) && !close(fd) && !rename(temporary, path));
    fd = open(root, O_RDONLY | O_DIRECTORY); assert(fd >= 0); assert(!fsync(fd) && !close(fd));
}
static inline transit_sdk_bytes read_saved(const char *root, const char *name) {
    char path[4096]; assert(snprintf(path, sizeof(path), "%s/%s", root, name) < (int)sizeof(path));
    FILE *file = fopen(path, "rb"); assert(file && !fseek(file, 0, SEEK_END)); long size = ftell(file); assert(size > 0 && size <= TRANSIT_SDK_STATION_CATALOG_ACTION_BYTES && !fseek(file, 0, SEEK_SET));
    uint8_t *data = (uint8_t *)malloc((size_t)size); assert(data && fread(data, 1, (size_t)size, file) == (size_t)size && !fclose(file));
    transit_sdk_bytes out = {data, (size_t)size}; return out;
}
static inline void uncertain(transit_sdk_error e) { assert(e.kind == TRANSIT_SDK_UNKNOWN_OUTCOME && e.has_native_status && e.native_status == 6); }
#endif
