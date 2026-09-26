#define _POSIX_C_SOURCE 200809L
#include <transit/sdk_examples.h>
#include <errno.h>
#include <fcntl.h>
#include <inttypes.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>
static int failed(transit_sdk_error error) {
    if (error.kind == TRANSIT_SDK_OK) return 0;
    fprintf(stderr, "Transit error %u during %s (native %u, code %s)\n", error.kind, error.phase, error.native_status, error.code); return 1;
}
static uint64_t number(const char *text) {
    if (!*text || strspn(text, "0123456789") != strlen(text)) exit(2);
    errno = 0; char *end; uint64_t value = strtoull(text, &end, 10); if (errno || *end) exit(2); return value;
}
static transit_sdk_error persist(void *context, const transit_station_mutation *mutation) {
    transit_sdk_buffer bytes = {0}; transit_sdk_error error = transit_station_mutation_export(mutation, &bytes); if (error.kind != TRANSIT_SDK_OK) return error;
    int file = open((const char *)context, O_WRONLY | O_CREAT | O_TRUNC, 0600);
    bool success = file >= 0; size_t offset = 0;
    while (success && offset < bytes.size) {
        const ssize_t written = write(file, bytes.data + offset, bytes.size - offset);
        if (written < 0 && errno == EINTR) continue; if (written <= 0) success = false; else offset += (size_t)written;
    }
    if (file >= 0) { if (fsync(file)) success = false; if (close(file)) success = false; }
    /* Persist the directory entry too before authorizing native dispatch. */
    const char *path = context; const char *slash = strrchr(path, '/');
    char *parent = slash ? strndup(path, slash == path ? 1 : (size_t)(slash - path)) : strdup(".");
    int directory = parent ? open(parent, O_RDONLY | O_DIRECTORY) : -1;
    if (directory < 0) success = false;
    else { if (fsync(directory)) success = false; if (close(directory)) success = false; }
    free(parent);
    transit_sdk_buffer_release(&bytes); if (!success) error.kind = TRANSIT_SDK_HANDLER_ERROR; return error;
}
static transit_sdk_error confirmed(void *context, const char *identity, transit_sdk_confirmation receipt) {
    (void)context; (void)identity; (void)receipt; return (transit_sdk_error){0};
}
int main(int argc, char **argv) {
    if (argc != 11) { fputs("Usage: transit-c-counter URL service|requester REALM PRINCIPAL PID GENERATION SEED_FILE PEER COMMITS PENDING_FILE\n", stderr); return 2; }
    transit_station_config config = {0}; config.client = transit_sdk_growing_config(argv[1]);
    if (failed(transit_sdk_process_make(number(argv[3]), number(argv[5]), &config.process))) return 2;
    config.credential = (transit_sdk_credential){config.process.realm, number(argv[4]), argv[7]}; config.generation = number(argv[6]); config.association = "data";
    transit_example_peer peer; if (failed(transit_sdk_process_make(config.process.realm, number(argv[8]), &peer.peer))) return 2;
    transit_station_handler handler; transit_station_codec codec;
    if (!strcmp(argv[2], "service")) { handler = transit_example_counter_handler(); codec = transit_example_counter_codec(); }
    else if (!strcmp(argv[2], "requester")) { handler = transit_example_requester_handler(&peer); codec = transit_example_requester_codec(); }
    else return 2;
    const transit_station_options options = {TRANSIT_FAILURE_STOP, TRANSIT_RECOVERY_PERSIST_BEFORE_DISPATCH, argv[10], persist, confirmed};
    transit_station_runner *runner = NULL; if (failed(transit_station_runner_open(&config, &handler, &codec, &options, &runner))) return 1;
    const uint64_t target = number(argv[9]); uint64_t commits = 0; int result = 0;
    for (size_t steps = 0; commits < target && steps < 1000; ++steps) {
        transit_station_event *event = NULL; transit_sdk_error error = transit_station_runner_next(runner, &event);
        if (failed(error)) { result = 1; break; }
        transit_station_event_info info; error = transit_station_event_inspect(event, &info); transit_station_event_destroy(event);
        if (failed(error)) { result = 1; break; }
        if (info.kind == TRANSIT_EVENT_COMMITTED) ++commits;
        else if (info.kind == TRANSIT_EVENT_NEEDS_RECOVERY || info.kind == TRANSIT_EVENT_BLOCKED) { fputs("Runner requires recovery; keep the persisted request and inspect current authority.\n", stderr); result = 1; break; }
        else if (info.kind == TRANSIT_EVENT_IDLE) { const struct timespec delay = {0, 10000000}; nanosleep(&delay, NULL); }
    }
    transit_station_event *closed = NULL; if (failed(transit_station_runner_close(runner, &closed))) result = 1;
    transit_station_event_destroy(closed); transit_station_runner_destroy(runner);
    if (commits != target) result = 1; printf("{\"commits\":%" PRIu64 "}\n", commits); return result;
}
