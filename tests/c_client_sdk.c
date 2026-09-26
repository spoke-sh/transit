#define _POSIX_C_SOURCE 200809L
#include <transit/client.h>
#include <assert.h>
#include <inttypes.h>
#include <pthread.h>
#include <stdatomic.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

static void ok(transit_sdk_error error) {
    if (error.kind != TRANSIT_SDK_OK) { fprintf(stderr, "SDK error %u during %s, native %u, code %s\n", error.kind, error.phase, error.native_status, error.code); abort(); }
}
static transit_sdk_bytes bytes(const transit_sdk_buffer *buffer) { return (transit_sdk_bytes){buffer->data, buffer->size}; }
static transit_sdk_buffer read_file(const char *path) {
    FILE *file = fopen(path, "rb"); assert(file);
    transit_sdk_buffer out = {malloc(262145), 0}; assert(out.data);
    out.size = fread(out.data, 1, 262145, file); assert(out.size && out.size <= 262144 && !ferror(file)); fclose(file); return out;
}
static void write_file(const char *path, const transit_sdk_buffer *buffer) {
    FILE *file = fopen(path, "wb"); assert(file); assert(fwrite(buffer->data, 1, buffer->size, file) == buffer->size); assert(!fclose(file));
}
static void nap(void) { struct timespec delay = {0, 10000000}; nanosleep(&delay, NULL); }
struct Task { transit_sdk_client *client; transit_sdk_pending_send *pending; transit_sdk_dispatch outcome; atomic_bool done; };
static void *owned_task(void *pointer) {
    struct Task *task = pointer;
    task->outcome = transit_sdk_client_dispatch(task->client, task->pending);
    assert(task->outcome.outcome == TRANSIT_SDK_ADMITTED);
    transit_sdk_shutdown shutdown; ok(transit_sdk_client_close(task->client, &shutdown));
    assert(shutdown.has_admission && shutdown.last_admission.position == task->outcome.position);
    atomic_store(&task->done, true); return NULL;
}
int main(int argc, char **argv) {
    assert(argc == 9);
    const char *mode = argv[1];
    transit_sdk_config config = transit_sdk_growing_config(argv[2]); config.timeout_ms = 3000;
    transit_sdk_credential credential = {72, 65536, argv[3]};
    transit_sdk_process peer; ok(transit_sdk_process_make(72, strtoull(argv[4], NULL, 10), &peer));
    transit_sdk_process invalid;
    assert(transit_sdk_process_make(72, 0, &invalid).kind == TRANSIT_SDK_INVALID_ARGUMENT);
    assert(transit_sdk_process_make(72, UINT64_C(1) << 53, &invalid).kind == TRANSIT_SDK_INVALID_ARGUMENT);
    transit_sdk_client *client = NULL;
    config.native_directory = "/missing-transit";
    assert(transit_sdk_client_open(&config, &client).kind == TRANSIT_SDK_INCOMPATIBLE_NATIVE && !client);
    config.native_directory = argv[8];
    transit_sdk_error incompatible = transit_sdk_client_open(&config, &client);
    assert(incompatible.kind == TRANSIT_SDK_INCOMPATIBLE_NATIVE && !strcmp(incompatible.phase, "native-version") && !client);
    config.native_directory = NULL;
    config.sdk_version = 99;
    assert(transit_sdk_client_open(&config, &client).kind == TRANSIT_SDK_INCOMPATIBLE_NATIVE && !client);
    config.sdk_version = TRANSIT_SDK_VERSION;
    ok(transit_sdk_client_open(&config, &client));
    if (!strcmp(mode, "first")) {
        transit_sdk_capabilities caps; ok(transit_sdk_client_capabilities(client, &credential, &caps));
        assert(caps.principal_sequence == 0 && caps.page_size == 8 && caps.retained_versions);
        uint8_t value[] = {'w','i','d','e'};
        transit_sdk_pending_send *pending = NULL;
        ok(transit_sdk_client_prepare_send(client, peer, (transit_sdk_bytes){value, sizeof(value)}, &credential, 1, &pending));
        transit_sdk_send_info info; ok(transit_sdk_pending_send_info(pending, &info));
        assert(info.peer.pid == peer.pid && info.mutation.sequence == 1 && strlen(info.mutation.identity) == 64);
        memset(value, 0, sizeof(value));
        transit_sdk_buffer frozen; ok(transit_sdk_pending_send_export(pending, &frozen)); write_file(argv[5], &frozen);
        transit_sdk_buffer copy; ok(transit_sdk_pending_send_export(pending, &copy)); memset(copy.data, 0, copy.size); transit_sdk_buffer_release(&copy);
        transit_sdk_dispatch outcome = transit_sdk_client_dispatch(client, pending);
        assert(outcome.outcome == TRANSIT_SDK_UNCERTAIN && outcome.error.native_status == 6);
        ok(transit_sdk_pending_send_export(pending, &copy)); assert(copy.size == frozen.size && !memcmp(copy.data, frozen.data, frozen.size));
        transit_sdk_buffer_release(&copy); transit_sdk_buffer_release(&frozen); transit_sdk_pending_send_destroy(pending);
    } else if (!strcmp(mode, "recover") || !strcmp(mode, "denied")) {
        transit_sdk_buffer frozen = read_file(argv[5]); transit_sdk_pending_send *pending = NULL;
        ok(transit_sdk_client_recover_send(client, bytes(&frozen), &pending));
        transit_sdk_dispatch result = transit_sdk_client_dispatch(client, pending);
        if (!strcmp(mode, "denied")) { assert(result.outcome == TRANSIT_SDK_DISPATCH_REJECTED && result.error.kind == TRANSIT_SDK_ACCESS_DENIED && result.error.native_status == 4); }
        else {
            assert(access(argv[3], F_OK) && result.outcome == TRANSIT_SDK_ADMITTED && result.position);
            printf("{\"position\":%" PRIu64 "}\n", result.position);
            assert(transit_sdk_client_dispatch(client, pending).position == result.position);
            transit_sdk_buffer spawn = read_file(argv[6]); transit_sdk_pending_send *bad = NULL;
            assert(transit_sdk_client_recover_send(client, bytes(&spawn), &bad).kind == TRANSIT_SDK_UNSUPPORTED_CAPABILITY && !bad);
            transit_sdk_pending_mutation *mutation = NULL;
            ok(transit_sdk_client_recover_mutation(client, bytes(&spawn), &mutation));
            transit_sdk_mutation_info info; ok(transit_sdk_pending_mutation_info(mutation, &info)); assert(!strcmp(info.command, "spawn"));
            transit_sdk_buffer exported; ok(transit_sdk_pending_mutation_export(mutation, &exported)); assert(exported.size == spawn.size && !memcmp(exported.data, spawn.data, spawn.size));
            transit_sdk_buffer_release(&exported); transit_sdk_pending_mutation_destroy(mutation); free(spawn.data);
            uint8_t *malformed = malloc(frozen.size + 1); assert(malformed); malformed[0] = ' '; memcpy(malformed + 1, frozen.data, frozen.size);
            assert(transit_sdk_client_recover_send(client, (transit_sdk_bytes){malformed, frozen.size + 1}, &bad).kind != TRANSIT_SDK_OK && !bad); free(malformed);
        }
        transit_sdk_pending_send_destroy(pending); free(frozen.data);
    } else if (!strcmp(mode, "async")) {
        transit_sdk_pending_send *pending = NULL;
        ok(transit_sdk_client_prepare_send(client, peer, (transit_sdk_bytes){(const uint8_t *)"async", 5}, &credential, 2, &pending));
        transit_sdk_buffer frozen; ok(transit_sdk_pending_send_export(pending, &frozen));
        struct Task task = { .client = client, .pending = pending, .done = ATOMIC_VAR_INIT(false) };
        pthread_t worker; assert(!pthread_create(&worker, NULL, owned_task, &task));
        int waited = 0; while (access(argv[7], F_OK)) { assert(++waited < 1500); nap(); }
        transit_sdk_capabilities caps;
        assert(transit_sdk_client_capabilities(client, &credential, &caps).kind == TRANSIT_SDK_BUSY);
        // The controller abandons observation until joining its owned task.
        int beats = 0; while (!atomic_load(&task.done)) { ++beats; assert(beats < 1500); nap(); }
        assert(!pthread_join(worker, NULL) && beats > 5);
        assert(transit_sdk_client_capabilities(client, &credential, &caps).kind == TRANSIT_SDK_CLOSED);
        transit_sdk_client *fresh; ok(transit_sdk_client_open(&config, &fresh));
        transit_sdk_pending_send *recovered; ok(transit_sdk_client_recover_send(fresh, bytes(&frozen), &recovered));
        transit_sdk_dispatch retry = transit_sdk_client_dispatch(fresh, recovered); assert(retry.outcome == TRANSIT_SDK_ADMITTED && retry.position == task.outcome.position);
        transit_sdk_pending_send_destroy(recovered); transit_sdk_client_destroy(fresh);
        transit_sdk_pending_send_destroy(pending); transit_sdk_buffer_release(&frozen);
        puts("{\"scenario\":\"blocking-owner-disposal\",\"observations\":{\"controller_wait_abandoned\":true,\"responsive_during_join\":true,\"owned_work_joined\":true,\"receipt_recovered\":true}}");
    } else abort();
    transit_sdk_shutdown shutdown; ok(transit_sdk_client_close(client, &shutdown)); transit_sdk_client_destroy(client);
}
