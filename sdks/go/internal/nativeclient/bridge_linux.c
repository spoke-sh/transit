//go:build linux && (amd64 || arm64) && cgo

#define _GNU_SOURCE
#include "bridge.h"
#include "api_generated.h"
#include <dlfcn.h>
#include <pthread.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>

/* Code images outlive all handles: Zig's detached I/O threads may still be
 * returning through an image after native destruction finishes. */
#define IMAGE_LIMIT 16
typedef struct image {
    char *path;
    struct stat identity;
    void *mapping;
    transit_go_api api;
    uint32_t status;
} image;
static image images[IMAGE_LIMIT];
static size_t image_count;
static pthread_mutex_t image_lock = PTHREAD_MUTEX_INITIALIZER;

static int same_file(const struct stat *a, const struct stat *b) {
    return a->st_dev == b->st_dev && a->st_ino == b->st_ino && a->st_size == b->st_size &&
           a->st_mtim.tv_sec == b->st_mtim.tv_sec && a->st_mtim.tv_nsec == b->st_mtim.tv_nsec &&
           a->st_ctim.tv_sec == b->st_ctim.tv_sec && a->st_ctim.tv_nsec == b->st_ctim.tv_nsec;
}

static uint32_t load_image(const char *path, transit_go_api **out) {
    uint32_t status = TRANSIT_STATUS_INCOMPATIBLE_VERSION;
    struct stat before, after;
    // The absolute configured name remains bound to its original file identity,
    // including when a symlink is replaced while the process is running.
    char *canonical = strdup(path);
    if (!canonical) return status;
    pthread_mutex_lock(&image_lock);
    if (stat(canonical, &before) || !S_ISREG(before.st_mode)) goto done;
    for (size_t i = 0; i < image_count; i++) {
        image *entry = &images[i];
        if (!strcmp(entry->path, canonical)) {
            if (same_file(&before, &entry->identity)) {
                status = entry->status;
                if (!status) *out = &entry->api;
            }
            goto done;
        }
    }
    if (image_count == IMAGE_LIMIT) goto done;
    void *mapping = dlopen(canonical, RTLD_NOW | RTLD_LOCAL);
    if (!mapping) goto done;
    image *entry = &images[image_count++];
    entry->mapping = mapping;
    entry->path = canonical;
    canonical = NULL;
    entry->identity = before;
    entry->status = status;
    if (stat(entry->path, &after) || !same_file(&before, &after)) goto done;
    TRANSIT_GO_LOAD_API(&entry->api, mapping, goto done);
    if (!entry->api.transit_client_abi_definition_matches(
            (const uint8_t *)TRANSIT_CLIENT_ABI_DEFINITION, strlen(TRANSIT_CLIENT_ABI_DEFINITION)) ||
        entry->api.transit_client_abi_version() != TRANSIT_CLIENT_ABI_VERSION ||
        !entry->api.transit_client_supports_kind(TRANSIT_KIND_GROWING_COMMAND) ||
        !entry->api.transit_client_supports_kind(TRANSIT_KIND_GROWING_QUERY)) goto done;
    status = entry->status = TRANSIT_STATUS_OK;
    *out = &entry->api;
done:
    pthread_mutex_unlock(&image_lock);
    free(canonical);
    return status;
}

struct transit_go_worker {
    pthread_t thread;
    pthread_mutex_t lock;
    pthread_cond_t changed;
    int ready, pending, stopping;
    uint32_t init_status, timeout, action, kind;
    const char *path;
    const uint8_t *url, *data, *seed;
    size_t url_size, size, stack_size;
    transit_go_api *api;
    transit_client *client;
    transit_go_result result;
};

static int copy_buffer(transit_go_api *api, transit_buffer *buffer, uint8_t **out, size_t *size) {
    *size = buffer ? api->transit_buffer_size(buffer) : 0;
    if (*size > TRANSIT_CLIENT_MAX_BODY) return 0;
    if (!*size) return 1;
    const uint8_t *source = api->transit_buffer_data(buffer);
    if (!source) return 0;
    *out = malloc(*size);
    if (!*out) return 0;
    memcpy(*out, source, *size);
    return 1;
}

static transit_go_result perform(transit_go_worker *worker) {
    transit_go_result result = {0};
    transit_go_api *api = worker->api;
    transit_operation *operation = NULL;
    transit_buffer *buffer = NULL, *metadata = NULL;
    int submitted = 0;
    if (worker->action == TRANSIT_GO_PREPARE || worker->action == TRANSIT_GO_QUERY) {
        result.status = api->transit_operation_prepare(worker->kind, worker->seed,
            worker->data, worker->size, &operation);
    } else {
        result.status = api->transit_operation_import(worker->data, worker->size, &operation);
    }
    if (result.status) goto done;
    if (worker->action == TRANSIT_GO_CALL || worker->action == TRANSIT_GO_QUERY) {
        submitted = worker->action == TRANSIT_GO_CALL;
        result.status = api->transit_client_call(worker->client, operation, &buffer);
    } else {
        result.status = api->transit_operation_metadata(operation, &metadata);
        if (!result.status) result.status = api->transit_operation_export(operation, &buffer);
    }
    if (!copy_buffer(api, buffer, &result.data, &result.size) ||
        !copy_buffer(api, metadata, &result.metadata, &result.metadata_size)) {
        // Failure to deliver an accepted response cannot establish rejection.
        if (!result.status) result.status = submitted ? TRANSIT_STATUS_UNCERTAIN : TRANSIT_STATUS_OUT_OF_MEMORY;
        free(result.data); free(result.metadata);
        result.data = result.metadata = NULL;
        result.size = result.metadata_size = 0;
    }
    if (result.status && result.size) {
        transit_buffer *diagnostic = NULL;
        const uint8_t path[] = "diagnostic";
        if (!api->transit_json_extract(result.data, result.size, path, sizeof(path)-1, 0, &diagnostic)) {
            result.diagnostic_valid = api->transit_diagnostic_validate(
                api->transit_buffer_data(diagnostic), api->transit_buffer_size(diagnostic));
        }
        api->transit_buffer_destroy(diagnostic);
    }
done:
    api->transit_buffer_destroy(metadata);
    api->transit_buffer_destroy(buffer);
    api->transit_operation_destroy(operation);
    return result;
}

static void *run(void *pointer) {
    transit_go_worker *worker = pointer;
    pthread_attr_t attributes;
    if (!pthread_getattr_np(pthread_self(), &attributes)) {
        pthread_attr_getstacksize(&attributes, &worker->stack_size);
        pthread_attr_destroy(&attributes);
    }
    worker->init_status = worker->stack_size < TRANSIT_CLIENT_MINIMUM_STACK_BYTES
        ? TRANSIT_STATUS_INVALID_ARGUMENT : load_image(worker->path, &worker->api);
    if (!worker->init_status) worker->init_status = worker->api->transit_client_create(
        TRANSIT_CLIENT_ABI_VERSION, worker->url, worker->url_size, worker->timeout, &worker->client);
    pthread_mutex_lock(&worker->lock);
    worker->ready = 1;
    pthread_cond_broadcast(&worker->changed);
    while (!worker->stopping) {
        while (!worker->pending && !worker->stopping) pthread_cond_wait(&worker->changed, &worker->lock);
        if (worker->stopping) break;
        pthread_mutex_unlock(&worker->lock);
        transit_go_result result = perform(worker);
        pthread_mutex_lock(&worker->lock);
        worker->result = result;
        worker->pending = 0;
        pthread_cond_broadcast(&worker->changed);
    }
    pthread_mutex_unlock(&worker->lock);
    if (worker->client) worker->api->transit_client_destroy(worker->client);
    return NULL;
}

uint32_t transit_go_open(const char *path, const uint8_t *url, size_t size,
                        uint32_t timeout, transit_go_worker **out) {
    *out = NULL;
    transit_go_worker *worker = calloc(1, sizeof(*worker));
    if (!worker) return TRANSIT_STATUS_OUT_OF_MEMORY;
    worker->path = path; worker->url = url; worker->url_size = size; worker->timeout = timeout;
    if (pthread_mutex_init(&worker->lock, NULL)) { free(worker); return TRANSIT_STATUS_OUT_OF_MEMORY; }
    if (pthread_cond_init(&worker->changed, NULL)) {
        pthread_mutex_destroy(&worker->lock); free(worker); return TRANSIT_STATUS_OUT_OF_MEMORY;
    }
    pthread_attr_t attributes;
    if (pthread_attr_init(&attributes)) goto failed;
    int error = pthread_attr_setstacksize(&attributes, TRANSIT_CLIENT_MINIMUM_STACK_BYTES);
    if (!error) error = pthread_create(&worker->thread, &attributes, run, worker);
    pthread_attr_destroy(&attributes);
    if (error) goto failed;
    pthread_mutex_lock(&worker->lock);
    while (!worker->ready) pthread_cond_wait(&worker->changed, &worker->lock);
    pthread_mutex_unlock(&worker->lock);
    uint32_t status = worker->init_status;
    if (status) { transit_go_close(worker); return status; }
    *out = worker;
    return TRANSIT_STATUS_OK;
failed:
    pthread_cond_destroy(&worker->changed); pthread_mutex_destroy(&worker->lock); free(worker);
    return TRANSIT_STATUS_OUT_OF_MEMORY;
}

transit_go_result transit_go_call(transit_go_worker *worker, uint32_t action, uint32_t kind,
                                 const uint8_t *seed, const uint8_t *data, size_t size) {
    pthread_mutex_lock(&worker->lock);
    if (worker->pending || worker->stopping) {
        pthread_mutex_unlock(&worker->lock);
        return (transit_go_result){.status = TRANSIT_STATUS_BUSY};
    }
    worker->action = action; worker->kind = kind; worker->seed = seed; worker->data = data; worker->size = size;
    worker->pending = 1;
    pthread_cond_broadcast(&worker->changed);
    while (worker->pending) pthread_cond_wait(&worker->changed, &worker->lock);
    transit_go_result result = worker->result;
    worker->seed = worker->data = NULL;
    pthread_mutex_unlock(&worker->lock);
    return result;
}

void transit_go_result_release(transit_go_result *result) {
    free(result->data); free(result->metadata);
    memset(result, 0, sizeof(*result));
}
void transit_go_close(transit_go_worker *worker) {
    if (!worker) return;
    pthread_mutex_lock(&worker->lock);
    worker->stopping = 1;
    pthread_cond_broadcast(&worker->changed);
    pthread_mutex_unlock(&worker->lock);
    pthread_join(worker->thread, NULL);
    pthread_cond_destroy(&worker->changed);
    pthread_mutex_destroy(&worker->lock);
    free(worker);
}
size_t transit_go_stack_size(transit_go_worker *worker) { return worker->stack_size; }
