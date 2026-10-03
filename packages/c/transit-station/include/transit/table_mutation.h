#ifndef TRANSIT_SDK_TABLE_MUTATION_H
#define TRANSIT_SDK_TABLE_MUTATION_H
#include <transit/station.h>
#ifdef __cplusplus
extern "C" {
#endif

/* Explicit writer connection. It confers neither ownership nor mutation access. */
typedef struct transit_station_table_mutation_connection {
    transit_sdk_process writer;
    transit_sdk_resource resource;
    uint32_t table;
} transit_station_table_mutation_connection;
typedef struct transit_station_table_mutation_reference { uint8_t bytes[72]; } transit_station_table_mutation_reference;
typedef struct transit_station_table_mutation_client transit_station_table_mutation_client;
typedef struct transit_station_table_mutation_compiled transit_station_table_mutation_compiled;
typedef struct transit_station_table_mutation_prepared transit_station_table_mutation_prepared;
typedef enum transit_station_table_mutation_permission {
    TRANSIT_TABLE_MUTATION_INSERT = 1, TRANSIT_TABLE_MUTATION_UPDATE = 2, TRANSIT_TABLE_MUTATION_DELETE = 4
} transit_station_table_mutation_permission;
typedef enum transit_station_table_mutation_phase {
    TRANSIT_TABLE_MUTATION_UPLOADING, TRANSIT_TABLE_MUTATION_SEALED,
    TRANSIT_TABLE_MUTATION_APPLIED, TRANSIT_TABLE_MUTATION_REJECTED, TRANSIT_TABLE_MUTATION_CANCELLED
} transit_station_table_mutation_phase;
typedef enum transit_station_table_mutation_reason {
    TRANSIT_TABLE_MUTATION_NONE, TRANSIT_TABLE_MUTATION_ROW_EXISTS, TRANSIT_TABLE_MUTATION_SOURCE_CHANGED,
    TRANSIT_TABLE_MUTATION_INVALID_REQUEST, TRANSIT_TABLE_MUTATION_DENIED, TRANSIT_TABLE_MUTATION_BUDGET
} transit_station_table_mutation_reason;
typedef enum transit_station_table_mutation_rejection {
    TRANSIT_TABLE_INPUT_INVALID_COMMAND, TRANSIT_TABLE_INPUT_DENIED, TRANSIT_TABLE_INPUT_IDENTITY_CONFLICT,
    TRANSIT_TABLE_INPUT_BUSY, TRANSIT_TABLE_INPUT_NOT_FOUND, TRANSIT_TABLE_INPUT_NOT_ACTIVE,
    TRANSIT_TABLE_INPUT_UPLOAD_CLOSED, TRANSIT_TABLE_INPUT_NOT_SEALED, TRANSIT_TABLE_INPUT_INVALID_PART,
    TRANSIT_TABLE_INPUT_INCOMPLETE_UPLOAD, TRANSIT_TABLE_INPUT_SOURCE_CHANGED, TRANSIT_TABLE_INPUT_STALE_POLICY
} transit_station_table_mutation_rejection;
typedef enum transit_station_table_mutation_observation { TRANSIT_TABLE_INPUT_PENDING, TRANSIT_TABLE_INPUT_PROCESSED } transit_station_table_mutation_observation;
typedef enum transit_station_table_mutation_control { TRANSIT_TABLE_MUTATION_APPLY, TRANSIT_TABLE_MUTATION_CANCEL } transit_station_table_mutation_control;
/* Inline owned values. Copying metadata/status never retains the client. */
typedef struct transit_station_table_mutation_description {
    transit_sdk_resource resource; uint32_t table; char names[2][17];
    transit_station_cell_kind value_type;
    uint64_t resource_revision, policy_revision; uint8_t declaration[32], permissions;
    bool has_active; uint64_t active;
} transit_station_table_mutation_description;
typedef struct transit_station_table_mutation_status {
    bool found; transit_station_table_mutation_reference reference;
    uint64_t principal; uint32_t table; uint8_t declaration[32]; uint64_t policy_revision;
    transit_station_table_mutation_phase phase; uint8_t affected_rows;
    transit_station_table_mutation_reason reason; uint64_t input;
    bool has_conflict; int64_t conflict_key; uint8_t conflict_row; /* one-based */
    transit_sdk_diagnostic diagnostic;
} transit_station_table_mutation_status;
typedef struct transit_station_table_mutation_disposition {
    bool found; uint64_t principal, input; uint8_t payload[32];
    transit_station_table_mutation_rejection reason; transit_sdk_diagnostic diagnostic;
} transit_station_table_mutation_disposition;

/* Imports copy input. Compiled request <=799 bytes, prepared UTF-8 <=8192 bytes.
 * Persist both canonical request and complete reference, and each opaque signed
 * command before submission. Shared Zig validates saved semantics before I/O. */
transit_sdk_error transit_station_table_mutation_compiled_import(transit_sdk_bytes, transit_station_table_mutation_reference, transit_station_table_mutation_compiled **out);
transit_sdk_error transit_station_table_mutation_compiled_get(const transit_station_table_mutation_compiled *, transit_sdk_bytes *request, transit_station_table_mutation_reference *reference);
void transit_station_table_mutation_compiled_destroy(transit_station_table_mutation_compiled *);
transit_sdk_error transit_station_table_mutation_prepared_import(transit_sdk_bytes, transit_station_table_mutation_prepared **out);
transit_sdk_error transit_station_table_mutation_prepared_bytes(const transit_station_table_mutation_prepared *, transit_sdk_bytes *out);
void transit_station_table_mutation_prepared_destroy(transit_station_table_mutation_prepared *);
/* Returned byte pointers borrow their owner; they survive client destruction. */
transit_sdk_error transit_station_table_mutation_open(const transit_sdk_config *, const transit_sdk_credential *, transit_station_table_mutation_connection, transit_station_table_mutation_client **out);
transit_sdk_error transit_station_table_mutation_close(transit_station_table_mutation_client *);
void transit_station_table_mutation_client_destroy(transit_station_table_mutation_client *);
transit_sdk_error transit_station_table_mutation_describe(transit_station_table_mutation_client *, transit_station_table_mutation_description *out);
transit_sdk_error transit_station_table_mutation_compile_sql(transit_station_table_mutation_client *, const char *name, const char *sql, uint64_t namespace_id, transit_station_table_mutation_compiled **out);
transit_sdk_error transit_station_table_mutation_prepare_next(transit_station_table_mutation_client *, const transit_station_table_mutation_compiled *, transit_station_table_mutation_prepared **out);
transit_sdk_error transit_station_table_mutation_prepare_control(transit_station_table_mutation_client *, transit_station_table_mutation_control, transit_station_table_mutation_reference, transit_station_table_mutation_prepared **out);
/* UNKNOWN_OUTCOME preserves the borrowed command: retry exactly those bytes.
 * Receipt means admission; null next means inspect status, not success. */
transit_sdk_error transit_station_table_mutation_submit(transit_station_table_mutation_client *, const transit_station_table_mutation_prepared *, uint64_t *position);
transit_sdk_error transit_station_table_mutation_observe(transit_station_table_mutation_client *, const transit_station_table_mutation_prepared *, uint64_t input, transit_station_table_mutation_observation *out);
transit_sdk_error transit_station_table_mutation_input_rejection(transit_station_table_mutation_client *, const transit_station_table_mutation_prepared *, uint64_t input, transit_station_table_mutation_disposition *out);
transit_sdk_error transit_station_table_mutation_status_read(transit_station_table_mutation_client *, transit_station_table_mutation_reference, transit_station_table_mutation_status *out);
/* Operations block on one bounded worker; overlap returns BUSY. Close joins.
 * Join caller threads before destroying/moving any borrowed owner. */
#ifdef __cplusplus
}
#endif
#endif
