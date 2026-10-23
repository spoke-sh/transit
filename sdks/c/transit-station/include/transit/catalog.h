#ifndef TRANSIT_SDK_CATALOG_H
#define TRANSIT_SDK_CATALOG_H
#include <transit/station.h>
#include <transit/logical.h>
#ifdef __cplusplus
extern "C" {
#endif

/* Native IDs retain the public-client counter bounds. Catalog, object, column,
 * operation, namespace and application revision identities are full uint64.
 * All tags have integer carriers so unknown foreign values fail normally. */
typedef struct transit_station_catalog_scope { transit_sdk_resource resource; uint64_t catalog; } transit_station_catalog_scope;
typedef struct transit_station_catalog_connection {
    transit_sdk_process owner; transit_station_catalog_scope scope;
    bool has_role; uint64_t role, namespace_id;
} transit_station_catalog_connection;
typedef struct transit_station_catalog_authority {
    uint64_t database_domain, schema_domain, table_domain, database, initial_schema_authority, initial_schema;
} transit_station_catalog_authority;
typedef struct transit_station_catalog_subject {
    uint64_t principal, login_role, role, credential_epoch, audience; uint8_t context[32];
} transit_station_catalog_subject;
typedef struct transit_station_catalog_limits { uint32_t record_bytes; uint64_t staging_bytes; uint32_t staging_records; } transit_station_catalog_limits;
typedef struct transit_station_catalog_configuration {
    transit_station_catalog_scope scope; transit_sdk_process owner; uint64_t administrator; transit_station_catalog_limits table_limits;
    transit_station_catalog_authority authority; char database_name[64];
} transit_station_catalog_configuration;
typedef struct transit_station_catalog_identity { uint64_t operation, namespace_id; } transit_station_catalog_identity;
typedef struct transit_station_catalog_basis { uint64_t object, revision; uint8_t schema_fingerprint[32]; } transit_station_catalog_basis;
/* Construction views borrow their trees during the call. max_characters == 0
 * means no declared length; default_value == NULL means no default. */
typedef uint32_t transit_station_catalog_encoding;
enum { TRANSIT_CATALOG_PLAIN, TRANSIT_CATALOG_BITPACKED, TRANSIT_CATALOG_RLE, TRANSIT_CATALOG_DICTIONARY, TRANSIT_CATALOG_FSST, TRANSIT_CATALOG_COMP, TRANSIT_CATALOG_COMP_3, TRANSIT_CATALOG_ZONED, TRANSIT_CATALOG_IBM_HFP, TRANSIT_CATALOG_EBCDIC };
typedef uint32_t transit_station_catalog_collation;
enum { TRANSIT_CATALOG_NONE, TRANSIT_CATALOG_UTF8_BINARY, TRANSIT_CATALOG_ASCII_CI, TRANSIT_CATALOG_EBCDIC_CP037, TRANSIT_CATALOG_ICU_ROOT };
typedef struct transit_station_catalog_column {
    uint64_t id; const char *name; const transit_logical_type_view *type; bool nullable;
    const transit_logical_cell_view *default_value; uint32_t max_characters;
    transit_station_catalog_encoding encoding; transit_station_catalog_collation collation;
} transit_station_catalog_column;
/* ADD allocates its stable column identity through the owning schema. */
typedef struct transit_station_catalog_column_spec {
    const char *name; const transit_logical_type_view *type; bool nullable;
    const transit_logical_cell_view *default_value; uint32_t max_characters;
    transit_station_catalog_encoding encoding; transit_station_catalog_collation collation;
} transit_station_catalog_column_spec;
typedef struct transit_station_catalog_schema {
    uint64_t object, revision, next_column; const transit_station_catalog_column *columns; size_t column_count;
    const uint64_t *primary_key; size_t primary_key_count;
} transit_station_catalog_schema;
typedef struct transit_station_catalog_assignment { uint64_t column; const transit_logical_cell_view *value; } transit_station_catalog_assignment;
/* A NULL assignment value is DEFAULT; a logical NULL is a non-NULL cell view. */
typedef struct transit_station_catalog_assignments { const transit_station_catalog_assignment *data; size_t size; } transit_station_catalog_assignments;
typedef uint32_t transit_station_catalog_predicate_kind;
enum { TRANSIT_CATALOG_ALL, TRANSIT_CATALOG_STATE, TRANSIT_CATALOG_COMPARE, TRANSIT_CATALOG_NOT, TRANSIT_CATALOG_AND, TRANSIT_CATALOG_OR };
typedef uint32_t transit_station_catalog_compare;
enum { TRANSIT_CATALOG_EQ, TRANSIT_CATALOG_NE, TRANSIT_CATALOG_LT, TRANSIT_CATALOG_LE, TRANSIT_CATALOG_GT, TRANSIT_CATALOG_GE };
typedef struct transit_station_catalog_predicate_term {
    transit_station_catalog_predicate_kind kind; uint64_t column;
    union { transit_logical_state state; struct { transit_station_catalog_compare op; transit_logical_atom value; } compare; } as;
} transit_station_catalog_predicate_term;
/* Postfix program; NULL data and zero size means no predicate. */
typedef struct transit_station_catalog_predicate { const transit_station_catalog_predicate_term *data; size_t size; } transit_station_catalog_predicate;
typedef uint32_t transit_station_catalog_change_kind;
enum { TRANSIT_CATALOG_ADD_COLUMN, TRANSIT_CATALOG_DROP_COLUMN, TRANSIT_CATALOG_RENAME_COLUMN, TRANSIT_CATALOG_DEFAULT, TRANSIT_CATALOG_NULLABLE, TRANSIT_CATALOG_TYPE, TRANSIT_CATALOG_PHYSICAL };
typedef struct transit_station_catalog_change {
    transit_station_catalog_change_kind kind; uint64_t column;
    union {
        transit_station_catalog_column_spec add;
        const char *name;
        const transit_logical_cell_view *default_value;
        bool nullable;
        struct { const transit_logical_type_view *type; uint32_t max_characters; } type;
        struct { transit_station_catalog_encoding encoding; transit_station_catalog_collation collation; } physical;
    } as;
} transit_station_catalog_change;
typedef uint32_t transit_station_catalog_kind;
enum { TRANSIT_CATALOG_CREATE, TRANSIT_CATALOG_ALTER, TRANSIT_CATALOG_RENAME, TRANSIT_CATALOG_DROP, TRANSIT_CATALOG_INSERT, TRANSIT_CATALOG_UPDATE, TRANSIT_CATALOG_DELETE };
typedef struct transit_station_catalog_action {
    transit_station_catalog_kind kind;
    union {
        struct { const transit_station_catalog_schema *schema; bool if_not_exists; } create;
        struct { transit_station_catalog_basis basis; transit_station_catalog_change change; } alter;
        struct { transit_station_catalog_basis basis; const char *name; } rename;
        struct { const transit_station_catalog_basis *basis; bool if_exists; } drop;
        struct { transit_station_catalog_basis basis; const transit_station_catalog_assignments *rows; size_t row_count; } insert;
        struct { transit_station_catalog_basis basis; transit_station_catalog_assignments assignments; transit_station_catalog_predicate predicate; } update;
        struct { transit_station_catalog_basis basis; transit_station_catalog_predicate predicate; } remove;
    } as;
} transit_station_catalog_action;
typedef struct transit_station_catalog_request { const char *name; transit_station_catalog_identity identity; transit_station_catalog_action action; } transit_station_catalog_request;
typedef uint32_t transit_station_catalog_dependency_kind;
enum { TRANSIT_CATALOG_QUERY_SOURCE, TRANSIT_CATALOG_WRITER, TRANSIT_CATALOG_WATCH, TRANSIT_CATALOG_MAINTAINED_RELATION, TRANSIT_CATALOG_HISTORY };
typedef struct transit_station_catalog_dependency {
    transit_station_catalog_scope scope; uint64_t object, identity; transit_sdk_process owner; transit_station_catalog_dependency_kind kind;
} transit_station_catalog_dependency;
typedef struct transit_station_catalog_metadata_commitment { uint32_t bytes; uint8_t digest[32]; } transit_station_catalog_metadata_commitment;
typedef struct transit_station_catalog_metadata {
    transit_station_catalog_scope scope; uint64_t namespace_id, object, revision; char name[256]; uint8_t schema_fingerprint[32];
    uint64_t principal, operation, admitted_input; transit_station_catalog_metadata_commitment commitment;
} transit_station_catalog_metadata;
typedef struct transit_station_catalog_head { uint64_t revision, rows, pending; } transit_station_catalog_head;
typedef struct transit_station_catalog_entry { transit_station_catalog_metadata metadata; transit_station_catalog_head head; } transit_station_catalog_entry;
typedef struct transit_station_catalog_definition_view {
    transit_station_catalog_metadata metadata; transit_station_catalog_head head; transit_station_catalog_schema schema; uint64_t authorization;
} transit_station_catalog_definition_view;
typedef struct transit_station_catalog_historical_view { transit_station_catalog_metadata metadata; transit_station_catalog_schema schema; } transit_station_catalog_historical_view;
/* Mandatory definition and original cut; never default these when restoring. */
typedef struct transit_station_catalog_cursor {
    char definition[65]; transit_station_catalog_scope scope; uint64_t resource_revision, after_object;
} transit_station_catalog_cursor;
typedef struct transit_station_catalog_page {
    uint64_t resource_revision; size_t count; transit_station_catalog_entry entries[8]; bool has_next; transit_station_catalog_cursor next;
} transit_station_catalog_page;
typedef struct transit_station_catalog_reference { char definition[65]; uint8_t digest[32]; } transit_station_catalog_reference;
typedef struct transit_station_catalog_intent {
    transit_station_catalog_reference reference; transit_station_catalog_scope scope; transit_sdk_process owner;
    uint64_t principal; transit_station_catalog_identity identity; uint64_t object; transit_station_catalog_kind kind;
} transit_station_catalog_intent;
typedef struct transit_station_catalog_counts { uint64_t matched, changed; } transit_station_catalog_counts;
typedef uint32_t transit_station_catalog_phase;
enum { TRANSIT_CATALOG_PREPARING, TRANSIT_CATALOG_DELEGATED, TRANSIT_CATALOG_BUILDING, TRANSIT_CATALOG_APPLIED, TRANSIT_CATALOG_UNCHANGED, TRANSIT_CATALOG_REJECTED, TRANSIT_CATALOG_CANCELLED };
typedef struct transit_station_catalog_outcome {
    transit_station_catalog_kind kind; uint64_t operation, object; bool has_actual_object; uint64_t actual_object;
    transit_station_catalog_phase phase; bool terminal, has_counts; transit_station_catalog_counts counts;
    uint64_t admitted_input; bool has_completed_input; uint64_t completed_input; transit_sdk_diagnostic diagnostic;
} transit_station_catalog_outcome;
typedef uint32_t transit_station_catalog_upload_phase;
enum { TRANSIT_CATALOG_UPLOADING, TRANSIT_CATALOG_SEALED, TRANSIT_CATALOG_READY, TRANSIT_CATALOG_UPLOAD_CANCELLED };
typedef struct transit_station_catalog_upload { transit_station_catalog_upload_phase phase; uint32_t received, total; } transit_station_catalog_upload;
typedef struct transit_station_catalog_state {
    bool has_outcome; transit_station_catalog_outcome outcome; bool has_upload; transit_station_catalog_upload upload;
} transit_station_catalog_state;
typedef uint32_t transit_station_catalog_disposition_kind;
enum { TRANSIT_CATALOG_INITIALIZED, TRANSIT_CATALOG_POLICY_APPLIED, TRANSIT_CATALOG_DEPENDENCY_APPLIED, TRANSIT_CATALOG_INVALID_COMMAND, TRANSIT_CATALOG_BLOCKED, TRANSIT_CATALOG_DENIED, TRANSIT_CATALOG_IDENTITY_CONFLICT, TRANSIT_CATALOG_STALE_POLICY };
typedef struct transit_station_catalog_disposition { bool found; uint64_t input; transit_station_catalog_disposition_kind outcome; transit_sdk_diagnostic diagnostic; } transit_station_catalog_disposition;
typedef uint32_t transit_station_catalog_observation;
enum { TRANSIT_CATALOG_PENDING, TRANSIT_CATALOG_PROCESSED };
typedef struct transit_station_catalog_progress { transit_station_catalog_observation observation; transit_station_catalog_disposition disposition; transit_station_catalog_state state; } transit_station_catalog_progress;
typedef uint32_t transit_station_catalog_control;
enum { TRANSIT_CATALOG_CANCEL_OPERATION, TRANSIT_CATALOG_CLEANUP_OPERATION, TRANSIT_CATALOG_CANCEL_UPLOAD, TRANSIT_CATALOG_COLLECT_UPLOAD };
typedef struct transit_station_catalog_capabilities {
    uint8_t version; char definition[65]; uint16_t max_columns, max_rows, max_sql_bytes;
    uint32_t max_intent_bytes, max_action_bytes; uint16_t max_prepared_bytes; uint8_t resident_intents;
} transit_station_catalog_capabilities;
typedef struct transit_station_catalog_description { transit_station_catalog_configuration configuration; transit_station_catalog_subject subject; uint64_t authorization_revision, resource_revision; } transit_station_catalog_description;
typedef struct transit_station_catalog_client transit_station_catalog_client;
typedef struct transit_station_catalog_saved_intent transit_station_catalog_saved_intent;
typedef struct transit_station_catalog_compiled transit_station_catalog_compiled;
typedef struct transit_station_catalog_prepared transit_station_catalog_prepared;
typedef struct transit_station_catalog_definition transit_station_catalog_definition;
typedef struct transit_station_catalog_historical transit_station_catalog_historical;
typedef struct transit_station_catalog_next transit_station_catalog_next;
typedef uint32_t transit_station_catalog_next_kind;
enum { TRANSIT_CATALOG_NEXT_SEND, TRANSIT_CATALOG_NEXT_RUNNING, TRANSIT_CATALOG_NEXT_TERMINAL, TRANSIT_CATALOG_NEXT_UPLOAD_CANCELLED };
typedef struct transit_station_catalog_next_view {
    transit_station_catalog_next_kind kind; const transit_station_catalog_prepared *prepared; const transit_station_catalog_outcome *outcome;
} transit_station_catalog_next_view;

/* Saved-intent imports copy mandatory definition and <=4,327,031 exact bytes.
 * Prepared imports copy <=8192 UTF-8 bytes. Persist these and each admitted
 * input position before progressing. Views remain owned after client close. */
transit_sdk_error transit_station_catalog_saved_import(const char *definition, transit_sdk_bytes, transit_station_catalog_saved_intent **out);
transit_sdk_error transit_station_catalog_saved_get(const transit_station_catalog_saved_intent *, const char **definition, transit_sdk_bytes *out);
void transit_station_catalog_saved_destroy(transit_station_catalog_saved_intent *);
transit_sdk_error transit_station_catalog_compiled_get(const transit_station_catalog_compiled *, transit_station_catalog_intent *out, const transit_station_catalog_saved_intent **saved);
void transit_station_catalog_compiled_destroy(transit_station_catalog_compiled *);
transit_sdk_error transit_station_catalog_prepared_import(transit_sdk_bytes, transit_station_catalog_prepared **out);
transit_sdk_error transit_station_catalog_prepared_bytes(const transit_station_catalog_prepared *, transit_sdk_bytes *out);
void transit_station_catalog_prepared_destroy(transit_station_catalog_prepared *);
transit_sdk_error transit_station_catalog_definition_get(const transit_station_catalog_definition *, const transit_station_catalog_definition_view **out);
void transit_station_catalog_definition_destroy(transit_station_catalog_definition *);
transit_sdk_error transit_station_catalog_historical_get(const transit_station_catalog_historical *, const transit_station_catalog_historical_view **out);
void transit_station_catalog_historical_destroy(transit_station_catalog_historical *);
transit_sdk_error transit_station_catalog_next_get(const transit_station_catalog_next *, transit_station_catalog_next_view *out);
void transit_station_catalog_next_destroy(transit_station_catalog_next *);

/* One active call per client. Close joins owned work; deferred POSIX cancellation
 * stays masked through output publication. Join users before destroying handles.
 * Lookup/history return NULL when absent. All failures clear their outputs. */
transit_sdk_error transit_station_catalog_open(const transit_sdk_config *, const transit_sdk_credential *, transit_station_catalog_connection, const char *table_service_url, transit_station_catalog_client **out);
transit_sdk_error transit_station_catalog_close(transit_station_catalog_client *);
void transit_station_catalog_client_destroy(transit_station_catalog_client *);
transit_sdk_error transit_station_catalog_capabilities_read(transit_station_catalog_client *, transit_station_catalog_capabilities *out);
transit_sdk_error transit_station_catalog_describe(transit_station_catalog_client *, transit_station_catalog_description *out);
transit_sdk_error transit_station_catalog_lookup(transit_station_catalog_client *, const char *name, transit_station_catalog_definition **out);
transit_sdk_error transit_station_catalog_definition_read(transit_station_catalog_client *, uint64_t object, uint64_t revision, transit_station_catalog_historical **out);
transit_sdk_error transit_station_catalog_list(transit_station_catalog_client *, const transit_station_catalog_cursor *, transit_station_catalog_page *out);
transit_sdk_error transit_station_catalog_compile_sql(transit_station_catalog_client *, const char *sql, transit_station_catalog_identity, const uint64_t *create_object, transit_station_catalog_compiled **out);
transit_sdk_error transit_station_catalog_prepare(transit_station_catalog_client *, const transit_station_catalog_request *, transit_station_catalog_compiled **out);
transit_sdk_error transit_station_catalog_load(transit_station_catalog_client *, const transit_station_catalog_saved_intent *, transit_station_catalog_intent *out);
transit_sdk_error transit_station_catalog_forget(transit_station_catalog_client *, const transit_station_catalog_reference *);
transit_sdk_error transit_station_catalog_next_read(transit_station_catalog_client *, const transit_station_catalog_reference *, transit_station_catalog_next **out);
transit_sdk_error transit_station_catalog_status_read(transit_station_catalog_client *, const transit_station_catalog_reference *, transit_station_catalog_state *out);
transit_sdk_error transit_station_catalog_prepare_resume(transit_station_catalog_client *, const transit_station_catalog_reference *, transit_station_catalog_prepared **out);
transit_sdk_error transit_station_catalog_prepare_control(transit_station_catalog_client *, const transit_station_catalog_reference *, transit_station_catalog_control, transit_station_catalog_prepared **out);
transit_sdk_error transit_station_catalog_prepare_initialize(transit_station_catalog_client *, const transit_station_catalog_configuration *, transit_station_catalog_prepared **out);
transit_sdk_error transit_station_catalog_prepare_dependency(transit_station_catalog_client *, const transit_station_catalog_dependency *, bool present, transit_station_catalog_prepared **out);
/* UNKNOWN_OUTCOME preserves the original prepared owner. Do not regenerate SQL.
 * An input position proves admission; applied outcome/counts remain separate. */
transit_sdk_error transit_station_catalog_submit(transit_station_catalog_client *, const transit_station_catalog_prepared *, uint64_t *position);
transit_sdk_error transit_station_catalog_observe(transit_station_catalog_client *, const transit_station_catalog_prepared *, uint64_t input, bool wait, transit_station_catalog_observation *out);
transit_sdk_error transit_station_catalog_input_disposition(transit_station_catalog_client *, const transit_station_catalog_prepared *, uint64_t input, transit_station_catalog_disposition *out);
transit_sdk_error transit_station_catalog_progress_read(transit_station_catalog_client *, const transit_station_catalog_reference *, const transit_station_catalog_prepared *, uint64_t input, bool wait, transit_station_catalog_progress *out);
#ifdef __cplusplus
}
#endif
#endif
