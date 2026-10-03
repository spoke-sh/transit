#ifndef TRANSIT_SDK_CLIENT_H
#define TRANSIT_SDK_CLIENT_H
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif
#include <transit/definition_client.h>
#define TRANSIT_SDK_VERSION 2u
/* Owned DIAGNOSTICS_V1 envelope. size==0 denotes absent; JSON is NUL terminated. */
typedef struct transit_sdk_diagnostic { size_t size; char json[32769]; } transit_sdk_diagnostic;
typedef enum transit_sdk_error_kind {
    TRANSIT_SDK_OK, TRANSIT_SDK_INVALID_ARGUMENT, TRANSIT_SDK_BUSY, TRANSIT_SDK_CLOSED,
    TRANSIT_SDK_INCOMPATIBLE_NATIVE, TRANSIT_SDK_UNSUPPORTED_CAPABILITY,
    TRANSIT_SDK_REJECTED, TRANSIT_SDK_ACCESS_DENIED, TRANSIT_SDK_STALE_OWNERSHIP,
    TRANSIT_SDK_PROCESS_RETIRED, TRANSIT_SDK_HISTORY_UNAVAILABLE, TRANSIT_SDK_READ_FAILED,
    TRANSIT_SDK_TURN_EXPIRED, TRANSIT_SDK_CODEC_ERROR, TRANSIT_SDK_HANDLER_ERROR,
    TRANSIT_SDK_MISSING_VALUE, TRANSIT_SDK_UNKNOWN_OUTCOME, TRANSIT_SDK_OUT_OF_MEMORY
} transit_sdk_error_kind;
typedef struct transit_sdk_error {
    transit_sdk_error_kind kind;
    bool has_native_status;
    uint32_t native_status;
    char code[257];
    char phase[64];
} transit_sdk_error;
typedef struct transit_sdk_process { uint64_t realm, pid; } transit_sdk_process;
typedef struct transit_sdk_resource { uint64_t realm, resource; } transit_sdk_resource;
typedef struct transit_sdk_bytes { const uint8_t *data; size_t size; } transit_sdk_bytes;
/* Only buffers returned by this SDK may be passed to buffer_release. */
typedef struct transit_sdk_buffer { uint8_t *data; size_t size; } transit_sdk_buffer;
typedef struct transit_sdk_config {
    uint32_t sdk_version;
    const char *url;
    uint32_t timeout_ms;
    const char *native_directory; /* NULL selects libraries beside the SDK. */
} transit_sdk_config;
typedef struct transit_sdk_credential { uint64_t realm, principal; const char *seed_file; } transit_sdk_credential;
typedef struct transit_sdk_capabilities {
    uint64_t realm, observed_at, principal_sequence, page_size, mutations_per_turn, outputs_per_turn;
    bool retained_versions, association_lookup, scoped_retry, station;
} transit_sdk_capabilities;
typedef struct transit_sdk_mutation_info {
    char identity[65];
    uint64_t realm, principal, sequence;
    char command[65];
} transit_sdk_mutation_info;
typedef struct transit_sdk_send_info { transit_sdk_mutation_info mutation; transit_sdk_process peer; } transit_sdk_send_info;
typedef struct transit_sdk_admission { uint64_t position; } transit_sdk_admission;
typedef struct transit_sdk_confirmation { uint64_t position; } transit_sdk_confirmation;
typedef enum transit_sdk_outcome {
    TRANSIT_SDK_ADMITTED, TRANSIT_SDK_CONFIRMED, TRANSIT_SDK_PREFLIGHT_FAILED,
    TRANSIT_SDK_DISPATCH_REJECTED, TRANSIT_SDK_UNCERTAIN
} transit_sdk_outcome;
/* On UNCERTAIN the original pending handle retains the exact retry material. */
typedef struct transit_sdk_dispatch {
    transit_sdk_outcome outcome;
    transit_sdk_error error;
    uint64_t position;
} transit_sdk_dispatch;
typedef struct transit_sdk_shutdown {
    bool has_admission, has_confirmation;
    transit_sdk_admission last_admission;
    transit_sdk_confirmation last_confirmation;
} transit_sdk_shutdown;
typedef struct transit_sdk_client transit_sdk_client;
typedef struct transit_sdk_pending_send transit_sdk_pending_send;
typedef struct transit_sdk_pending_mutation transit_sdk_pending_mutation;

transit_sdk_config transit_sdk_growing_config(const char *url);
transit_sdk_error transit_sdk_process_make(uint64_t realm, uint64_t pid, transit_sdk_process *out);
transit_sdk_error transit_sdk_resource_make(uint64_t realm, uint64_t resource, transit_sdk_resource *out);
void transit_sdk_buffer_release(transit_sdk_buffer *buffer);
transit_sdk_error transit_sdk_client_open(const transit_sdk_config *config, transit_sdk_client **out);
transit_sdk_error transit_sdk_client_capabilities(transit_sdk_client *client, const transit_sdk_credential *credential, transit_sdk_capabilities *out);
transit_sdk_error transit_sdk_client_prepare_send(transit_sdk_client *client, transit_sdk_process peer, transit_sdk_bytes value, const transit_sdk_credential *credential, uint64_t sequence, transit_sdk_pending_send **out);
transit_sdk_error transit_sdk_client_recover_send(transit_sdk_client *client, transit_sdk_bytes bytes, transit_sdk_pending_send **out);
transit_sdk_error transit_sdk_client_recover_mutation(transit_sdk_client *client, transit_sdk_bytes bytes, transit_sdk_pending_mutation **out);
transit_sdk_error transit_sdk_pending_send_info(const transit_sdk_pending_send *pending, transit_sdk_send_info *out);
transit_sdk_error transit_sdk_pending_mutation_info(const transit_sdk_pending_mutation *pending, transit_sdk_mutation_info *out);
transit_sdk_error transit_sdk_pending_send_export(const transit_sdk_pending_send *pending, transit_sdk_buffer *out);
transit_sdk_error transit_sdk_pending_mutation_export(const transit_sdk_pending_mutation *pending, transit_sdk_buffer *out);
void transit_sdk_pending_send_destroy(transit_sdk_pending_send *pending);
void transit_sdk_pending_mutation_destroy(transit_sdk_pending_mutation *pending);
transit_sdk_dispatch transit_sdk_client_dispatch(transit_sdk_client *client, const transit_sdk_pending_send *pending);
transit_sdk_dispatch transit_sdk_client_dispatch_mutation(transit_sdk_client *client, const transit_sdk_pending_mutation *pending);
/* close may join an admitted call. destroy requires exclusive handle ownership. */
transit_sdk_error transit_sdk_client_close(transit_sdk_client *client, transit_sdk_shutdown *out);
void transit_sdk_client_destroy(transit_sdk_client *client);
#ifdef __cplusplus
}
#endif
#endif
