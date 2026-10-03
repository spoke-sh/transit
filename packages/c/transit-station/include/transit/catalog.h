#ifndef TRANSIT_SDK_CATALOG_H
#define TRANSIT_SDK_CATALOG_H
#include <transit/station.h>
#ifdef __cplusplus
extern "C" {
#endif

/* Values own all fields inline. Names are nonempty, terminated strings <=16 bytes.
 * Full-width catalog/operation/object/revision IDs are independent of native IDs. */
typedef struct transit_station_catalog_scope { transit_sdk_resource resource; uint64_t catalog; } transit_station_catalog_scope;
typedef struct transit_station_catalog_connection { transit_sdk_process owner; transit_station_catalog_scope scope; } transit_station_catalog_connection;
typedef struct transit_station_catalog_configuration {
    transit_station_catalog_scope scope; transit_sdk_process owner; uint64_t administrator;
} transit_station_catalog_configuration;
typedef struct transit_station_catalog_schema { char names[2][17]; transit_station_cell_kind value_type; } transit_station_catalog_schema;
typedef struct transit_station_catalog_create_table {
    transit_station_catalog_scope scope; uint64_t operation, object; uint32_t table;
    char name[17]; transit_station_catalog_schema schema;
} transit_station_catalog_create_table;
typedef struct transit_station_catalog_policy {
    transit_station_catalog_scope scope; uint64_t principal, revision; bool inspect, create;
} transit_station_catalog_policy;
typedef struct transit_station_catalog_policy_change { uint64_t expected_revision; transit_station_catalog_policy policy; } transit_station_catalog_policy_change;
typedef enum transit_station_catalog_observation { TRANSIT_CATALOG_PENDING, TRANSIT_CATALOG_PROCESSED } transit_station_catalog_observation;
typedef enum transit_station_catalog_outcome {
    TRANSIT_CATALOG_APPLIED, TRANSIT_CATALOG_NAME_CONFLICT, TRANSIT_CATALOG_OBJECT_CONFLICT, TRANSIT_CATALOG_TABLE_CONFLICT
} transit_station_catalog_outcome;
typedef enum transit_station_catalog_origin { TRANSIT_CATALOG_EXTERNAL, TRANSIT_CATALOG_PROCESS, TRANSIT_CATALOG_EFFECT } transit_station_catalog_origin;
typedef enum transit_station_catalog_disposition_outcome {
    TRANSIT_CATALOG_INITIALIZED, TRANSIT_CATALOG_POLICY_APPLIED, TRANSIT_CATALOG_INVALID_COMMAND,
    TRANSIT_CATALOG_DENIED, TRANSIT_CATALOG_IDENTITY_CONFLICT, TRANSIT_CATALOG_STALE_POLICY
} transit_station_catalog_disposition_outcome;
typedef struct transit_station_catalog_capabilities {
    uint8_t version; char definition[65]; bool initialize, create_table, conditional_policy, current_metadata;
    uint16_t max_saved_bytes; uint8_t table_columns;
} transit_station_catalog_capabilities;
typedef struct transit_station_catalog_description {
    transit_station_catalog_configuration configuration; transit_station_catalog_policy policy; uint64_t resource_revision;
} transit_station_catalog_description;
typedef struct transit_station_catalog_table_source { uint32_t table; transit_station_catalog_schema schema; } transit_station_catalog_table_source;
typedef struct transit_station_catalog_definition {
    bool found; transit_station_catalog_scope scope; uint64_t object, revision; char name[17];
    transit_station_catalog_table_source source; uint64_t principal, operation, input;
} transit_station_catalog_definition;
/* All cursor fields are mandatory when restoring; never default definition. */
typedef struct transit_station_catalog_cursor {
    char definition[65]; transit_station_catalog_scope scope; uint64_t resource_revision; char after[17];
} transit_station_catalog_cursor;
typedef struct transit_station_catalog_page {
    uint64_t resource_revision; uint8_t count; transit_station_catalog_definition entries[8];
    bool has_next; transit_station_catalog_cursor next;
} transit_station_catalog_page;
typedef struct transit_station_catalog_receipt {
    bool found; transit_station_catalog_create_table request; uint64_t principal, input; transit_station_catalog_outcome outcome;
    transit_sdk_diagnostic diagnostic;
} transit_station_catalog_receipt;
typedef struct transit_station_catalog_disposition {
    bool found; transit_station_catalog_scope scope; transit_station_catalog_origin origin; uint64_t principal, input;
    uint8_t payload[32]; transit_station_catalog_disposition_outcome outcome;
    transit_sdk_diagnostic diagnostic;
} transit_station_catalog_disposition;
typedef struct transit_station_catalog_client transit_station_catalog_client;
typedef struct transit_station_catalog_compiled transit_station_catalog_compiled;
typedef struct transit_station_catalog_prepared transit_station_catalog_prepared;

/* Imports copy their input. Byte getters borrow their owner, independently of
 * the client. Canonical compiled bytes are review data, <=256 bytes; prepared
 * signed text is <=8192 bytes and must be saved unchanged before submission. */
transit_sdk_error transit_station_catalog_compiled_import(const transit_station_catalog_create_table *, transit_sdk_bytes canonical, transit_station_catalog_compiled **out);
transit_sdk_error transit_station_catalog_compiled_get(const transit_station_catalog_compiled *, transit_station_catalog_create_table *request, transit_sdk_bytes *canonical);
void transit_station_catalog_compiled_destroy(transit_station_catalog_compiled *);
transit_sdk_error transit_station_catalog_prepared_import(transit_sdk_bytes, transit_station_catalog_prepared **out);
transit_sdk_error transit_station_catalog_prepared_bytes(const transit_station_catalog_prepared *, transit_sdk_bytes *out);
void transit_station_catalog_prepared_destroy(transit_station_catalog_prepared *);

/* One active call per client; overlap returns BUSY. Close joins owned work.
 * Join caller threads before destroying handles or their borrowed inputs. */
transit_sdk_error transit_station_catalog_open(const transit_sdk_config *, const transit_sdk_credential *, transit_station_catalog_connection, transit_station_catalog_client **out);
transit_sdk_error transit_station_catalog_close(transit_station_catalog_client *);
void transit_station_catalog_client_destroy(transit_station_catalog_client *);
transit_sdk_error transit_station_catalog_capabilities_read(transit_station_catalog_client *, transit_station_catalog_capabilities *out);
transit_sdk_error transit_station_catalog_describe(transit_station_catalog_client *, transit_station_catalog_description *out);
/* Metadata is owned inline; failure clears out. NULL cursor starts a listing.
 * Continuation requires unchanged revision and current grants. */
transit_sdk_error transit_station_catalog_lookup(transit_station_catalog_client *, const char *name, transit_station_catalog_definition *out);
transit_sdk_error transit_station_catalog_definition_read(transit_station_catalog_client *, uint64_t object, uint64_t revision, transit_station_catalog_definition *out);
transit_sdk_error transit_station_catalog_list(transit_station_catalog_client *, const transit_station_catalog_cursor *, transit_station_catalog_page *out);
transit_sdk_error transit_station_catalog_compile_sql(transit_station_catalog_client *, const char *sql, uint64_t operation, uint64_t object, uint32_t table, transit_station_catalog_compiled **out);
transit_sdk_error transit_station_catalog_prepare_initialize(transit_station_catalog_client *, const transit_station_catalog_configuration *, transit_station_catalog_prepared **out);
transit_sdk_error transit_station_catalog_prepare_create(transit_station_catalog_client *, const transit_station_catalog_create_table *, transit_station_catalog_prepared **out);
transit_sdk_error transit_station_catalog_prepare_policy(transit_station_catalog_client *, const transit_station_catalog_policy_change *, transit_station_catalog_prepared **out);
/* UNKNOWN_OUTCOME retains the borrowed command. Retry those identical bytes.
 * A position is admission; processed input and applied creation remain separate. */
transit_sdk_error transit_station_catalog_submit(transit_station_catalog_client *, const transit_station_catalog_prepared *, uint64_t *position);
transit_sdk_error transit_station_catalog_observe(transit_station_catalog_client *, const transit_station_catalog_prepared *, uint64_t input, transit_station_catalog_observation *out);
transit_sdk_error transit_station_catalog_input_disposition(transit_station_catalog_client *, const transit_station_catalog_prepared *, uint64_t input, transit_station_catalog_disposition *out);
transit_sdk_error transit_station_catalog_status_read(transit_station_catalog_client *, const transit_station_catalog_create_table *original, transit_station_catalog_receipt *out);

#ifdef __cplusplus
}
#endif
#endif
