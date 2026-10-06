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
static inline void persist_saved(const char *root, const transit_station_catalog_saved_intent *saved) {
    const char *definition = NULL; transit_sdk_bytes bytes; checked(transit_station_catalog_saved_get(saved, &definition, &bytes));
    /* Both mandatory fields are durable before any signed step is submitted. */
    persist(root, "intent.bin", bytes);
    transit_sdk_bytes tag = {(const uint8_t *)definition, strlen(definition)}; persist(root, "intent.definition", tag);
}
static inline void persist_receipt(const char *root, uint64_t position) {
    char value[32]; int size = snprintf(value, sizeof(value), "%llu", (unsigned long long)position); assert(size > 0 && size < (int)sizeof(value));
    transit_sdk_bytes bytes = {(const uint8_t *)value, (size_t)size}; persist(root, "receipt", bytes);
}
static inline transit_station_catalog_identity identity(uint64_t base, uint64_t offset) {
    transit_station_catalog_identity out = {base + offset, base + offset + 100000}; return out;
}
static inline transit_station_catalog_basis basis(const transit_station_catalog_metadata *v) {
    transit_station_catalog_basis out; memset(&out, 0, sizeof(out)); out.object = v->object; out.revision = v->revision; memcpy(out.schema_fingerprint, v->schema_fingerprint, 32); return out;
}
static inline int outcome_equal(const transit_station_catalog_outcome *a, const transit_station_catalog_outcome *b) {
    return a->kind == b->kind && a->operation == b->operation && a->object == b->object && a->has_actual_object == b->has_actual_object && a->actual_object == b->actual_object &&
        a->phase == b->phase && a->terminal == b->terminal && a->has_counts == b->has_counts && a->counts.matched == b->counts.matched && a->counts.changed == b->counts.changed &&
        a->admitted_input == b->admitted_input && a->has_completed_input == b->has_completed_input && a->completed_input == b->completed_input &&
        a->diagnostic.size == b->diagnostic.size && !memcmp(a->diagnostic.json, b->diagnostic.json, a->diagnostic.size);
}
#endif
