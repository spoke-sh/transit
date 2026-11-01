#ifndef TRANSIT_SDK_CATALOG_H
#define TRANSIT_SDK_CATALOG_H
#include <transit/station.h>
#include <transit/logical.h>
#ifdef __cplusplus
extern "C" {
#endif

/* Native resource/audience/principal/namespace IDs retain native counter bounds.
 * Catalog, branch, object, operation and accepted positions use full uint64. */
typedef struct transit_station_catalog_scope { transit_sdk_resource resource; uint64_t catalog; } transit_station_catalog_scope;
typedef struct transit_station_catalog_connection { transit_station_catalog_scope scope; uint64_t audience, branch; bool has_role; uint64_t role; } transit_station_catalog_connection;
typedef struct transit_station_catalog_identity { uint64_t operation, namespace_id; } transit_station_catalog_identity;
typedef struct transit_station_catalog_authority { uint64_t database_domain, schema_domain, table_domain, stream_domain, queue_domain, kv_domain, database, initial_schema_authority, initial_schema; } transit_station_catalog_authority;
typedef struct transit_station_catalog_subject { uint64_t principal, login_role, role, credential_epoch, audience; uint8_t context[32]; } transit_station_catalog_subject;
typedef struct transit_station_catalog_limits { uint32_t record_bytes; uint64_t staging_bytes; uint32_t staging_records; } transit_station_catalog_limits;
typedef struct transit_station_catalog_position { uint64_t partition, next_lsn; } transit_station_catalog_position;
typedef struct transit_station_catalog_object { transit_station_catalog_scope scope; uint64_t branch, object; } transit_station_catalog_object;
typedef struct transit_station_catalog_interpretation { transit_station_catalog_object object; uint64_t revision; uint8_t digest[32]; } transit_station_catalog_interpretation;
typedef struct transit_station_catalog_content { uint64_t bytes; uint8_t sha256[32]; } transit_station_catalog_content;
typedef struct transit_station_catalog_stored { transit_station_catalog_interpretation interpretation; transit_station_catalog_content content; uint8_t schema_fingerprint[32]; bool retired; } transit_station_catalog_stored;
typedef uint32_t transit_station_catalog_ingestion;
enum { TRANSIT_CATALOG_POINT, TRANSIT_CATALOG_BULK };
typedef uint32_t transit_station_catalog_dialect;
enum { TRANSIT_CATALOG_TRANSIT, TRANSIT_CATALOG_MYSQL };
typedef struct transit_station_catalog_basis transit_station_catalog_basis;
typedef struct transit_station_catalog_saved_intent transit_station_catalog_saved_intent;
typedef struct transit_station_catalog_reference transit_station_catalog_reference;
typedef struct transit_station_catalog_cursor transit_station_catalog_cursor;
typedef struct transit_station_catalog_snapshot_owner transit_station_catalog_snapshot_owner;
typedef struct transit_station_catalog_snapshot_acquisition transit_station_catalog_snapshot_acquisition;
typedef struct transit_station_catalog_snapshot transit_station_catalog_snapshot;
typedef struct transit_station_catalog_intent transit_station_catalog_intent;
typedef struct transit_station_catalog_compiled transit_station_catalog_compiled;
typedef struct transit_station_catalog_metadata transit_station_catalog_metadata;
typedef struct transit_station_catalog_namespace_page transit_station_catalog_namespace_page;
typedef struct transit_station_catalog_table_page transit_station_catalog_table_page;
typedef struct transit_station_catalog_observation transit_station_catalog_observation;
typedef struct transit_station_catalog_preview transit_station_catalog_preview;
typedef struct transit_station_catalog_snapshot_status transit_station_catalog_snapshot_status;
typedef struct transit_station_catalog_snapshot_metadata transit_station_catalog_snapshot_metadata;
typedef struct transit_station_catalog_client transit_station_catalog_client;
/* Construction views borrow their trees during the call. max_characters == 0
 * means no declared length; default_value == NULL means no default. */
typedef uint32_t transit_station_catalog_encoding;
enum { TRANSIT_CATALOG_PLAIN, TRANSIT_CATALOG_BITPACKED, TRANSIT_CATALOG_RLE, TRANSIT_CATALOG_DICTIONARY, TRANSIT_CATALOG_FSST, TRANSIT_CATALOG_COMP, TRANSIT_CATALOG_COMP_3, TRANSIT_CATALOG_ZONED, TRANSIT_CATALOG_IBM_HFP, TRANSIT_CATALOG_EBCDIC };
typedef uint32_t transit_station_catalog_collation;
enum { TRANSIT_CATALOG_NONE, TRANSIT_CATALOG_UTF8_BINARY, TRANSIT_CATALOG_ASCII_CI, TRANSIT_CATALOG_EBCDIC_CP037, TRANSIT_CATALOG_ICU_ROOT, TRANSIT_CATALOG_EBCDIC_037_PAD, TRANSIT_CATALOG_EBCDIC_1047_NOPAD };
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
    transit_station_catalog_ingestion ingestion; /* INSERT/UPDATE/DELETE only. */
    union {
        struct { const transit_station_catalog_schema *schema; bool if_not_exists; } create;
        struct { const transit_station_catalog_basis *basis; transit_station_catalog_change change; } alter;
        struct { const transit_station_catalog_basis *basis; const char *name; } rename;
        struct { const transit_station_catalog_basis *basis; bool if_exists; } drop;
        struct { const transit_station_catalog_basis *basis; const transit_station_catalog_assignments *rows; size_t row_count; } insert;
        struct { const transit_station_catalog_basis *basis; transit_station_catalog_assignments assignments; transit_station_catalog_predicate predicate; } update;
        struct { const transit_station_catalog_basis *basis; transit_station_catalog_predicate predicate; } remove;
    } as;
} transit_station_catalog_action;

typedef struct transit_station_catalog_request { const char *name; transit_station_catalog_identity identity; transit_station_catalog_action action; } transit_station_catalog_request;
typedef struct transit_station_catalog_counts { uint64_t matched, changed; } transit_station_catalog_counts;
typedef struct transit_station_catalog_configuration { transit_station_catalog_scope scope; uint64_t branch, partition, audience; transit_station_catalog_authority authority; char database_name[256], initial_schema_name[256]; } transit_station_catalog_configuration;
typedef struct transit_station_catalog_description { transit_station_catalog_configuration configuration; transit_station_catalog_subject subject; uint64_t policy_revision; } transit_station_catalog_description;
typedef struct transit_station_catalog_capabilities { uint32_t version; char definition[65]; uint32_t max_columns, max_rows, max_sql_bytes, max_intent_bytes, max_action_bytes, metadata_page_entries, resident_intents; } transit_station_catalog_capabilities;
typedef uint32_t transit_station_catalog_work_kind;
enum { TRANSIT_CATALOG_TABLE, TRANSIT_CATALOG_NAME_ASSERTION };
typedef uint32_t transit_station_catalog_observation_kind;
enum { TRANSIT_CATALOG_DDL, TRANSIT_CATALOG_ROWS, TRANSIT_CATALOG_NAME_OBSERVATION };
typedef uint32_t transit_station_catalog_operation_state;
enum { TRANSIT_CATALOG_NOT_OBSERVED, TRANSIT_CATALOG_ADMITTED, TRANSIT_CATALOG_REJECTED, TRANSIT_CATALOG_CANCELLED, TRANSIT_CATALOG_COMMITTED, TRANSIT_CATALOG_UNCHANGED };
typedef uint32_t transit_station_catalog_phase;
enum { TRANSIT_CATALOG_PHASE_ADMITTED, TRANSIT_CATALOG_READY, TRANSIT_CATALOG_SETTLED, TRANSIT_CATALOG_PHASE_REJECTED, TRANSIT_CATALOG_PHASE_CANCELLED };
typedef uint32_t transit_station_catalog_reason;
enum { TRANSIT_CATALOG_REASON_NONE, TRANSIT_CATALOG_NAME_CONFLICT, TRANSIT_CATALOG_OBJECT_CONFLICT, TRANSIT_CATALOG_STALE_DEFINITION, TRANSIT_CATALOG_STALE_DATA, TRANSIT_CATALOG_DEPENDENCY, TRANSIT_CATALOG_CONSTRAINT, TRANSIT_CATALOG_DEFINITION_CHANGED, TRANSIT_CATALOG_DATA_CHANGED, TRANSIT_CATALOG_DUPLICATE_KEY, TRANSIT_CATALOG_MISSING_ROW, TRANSIT_CATALOG_INVALID_ROWS, TRANSIT_CATALOG_WORK_LIMIT, TRANSIT_CATALOG_CONDITION_CHANGED };
typedef uint32_t transit_station_catalog_evolution_work;
enum { TRANSIT_CATALOG_METADATA, TRANSIT_CATALOG_VALIDATE_ROWS, TRANSIT_CATALOG_REWRITE_ROWS };
typedef struct transit_station_catalog_basis_view { transit_station_catalog_connection connection; uint64_t principal, namespace_id; char name[256]; transit_station_catalog_stored interpretation; } transit_station_catalog_basis_view;
typedef struct transit_station_catalog_reference_view { transit_station_catalog_connection connection; uint64_t principal; transit_station_catalog_identity identity; transit_station_catalog_work_kind kind; } transit_station_catalog_reference_view;
typedef struct transit_station_catalog_intent_view { transit_station_catalog_work_kind kind; transit_station_catalog_identity identity; const transit_station_catalog_saved_intent *saved; } transit_station_catalog_intent_view;
typedef struct transit_station_catalog_metadata_view { const transit_station_catalog_basis *basis; uint64_t authorization; transit_station_catalog_position position; uint64_t changed_lsn, row_count; transit_station_catalog_schema schema; } transit_station_catalog_metadata_view;
typedef struct transit_station_catalog_cursor_view { transit_station_catalog_position position; uint64_t after; } transit_station_catalog_cursor_view;
typedef struct transit_station_catalog_namespace { transit_station_catalog_scope scope; uint64_t id, authorization, revision; char name[256]; bool retired; } transit_station_catalog_namespace;
typedef struct transit_station_catalog_entry { transit_station_catalog_interpretation interpretation; uint64_t namespace_id; char name[256]; transit_station_catalog_position position; uint64_t changed_lsn; } transit_station_catalog_entry;
typedef struct transit_station_catalog_namespace_page_view { transit_station_catalog_position position; size_t count; transit_station_catalog_namespace entries[8]; const transit_station_catalog_cursor *next; } transit_station_catalog_namespace_page_view;
typedef struct transit_station_catalog_table_page_view { transit_station_catalog_position position; size_t count; transit_station_catalog_entry entries[8]; const transit_station_catalog_cursor *next; } transit_station_catalog_table_page_view; /* Independent Table positions. */
typedef struct transit_station_catalog_commit { transit_station_catalog_stored definition; transit_station_catalog_position position; uint64_t matched, affected, live_rows; } transit_station_catalog_commit;
typedef struct transit_station_catalog_observation_view { transit_station_catalog_observation_kind kind; transit_station_catalog_operation_state state; const transit_station_catalog_reference *reference; bool has_commit; transit_station_catalog_commit commit; bool has_phase; transit_station_catalog_phase phase; bool has_reason; transit_station_catalog_reason reason; bool has_position; transit_station_catalog_position position; } transit_station_catalog_observation_view;
typedef struct transit_station_catalog_current { transit_station_catalog_stored definition; transit_station_catalog_position position; uint64_t changed_lsn, row_count; } transit_station_catalog_current;
typedef struct transit_station_catalog_preview_view { transit_station_catalog_observation_kind kind; transit_station_catalog_position position; bool has_current; transit_station_catalog_current current; transit_station_catalog_interpretation current_name; bool has_reason; transit_station_catalog_reason reason; bool has_work; transit_station_catalog_evolution_work work; bool rebuild_key, has_schema_fingerprint; uint8_t schema_fingerprint[32]; bool matches; } transit_station_catalog_preview_view;
typedef struct transit_station_catalog_read_authority { uint64_t database, schema, table; } transit_station_catalog_read_authority;
typedef struct transit_station_catalog_snapshot_owner_view { transit_station_catalog_connection connection; uint64_t principal; transit_station_catalog_object object; uint64_t operation; } transit_station_catalog_snapshot_owner_view;
typedef struct transit_station_catalog_snapshot_acquisition_view { const transit_station_catalog_snapshot_owner *owner; transit_station_catalog_position expected; } transit_station_catalog_snapshot_acquisition_view;
typedef struct transit_station_catalog_snapshot_view { const transit_station_catalog_snapshot_owner *owner; transit_station_catalog_content content; } transit_station_catalog_snapshot_view;
typedef struct transit_station_catalog_snapshot_status_view { const transit_station_catalog_snapshot_owner *owner; transit_station_catalog_interpretation current_interpretation; transit_station_catalog_position current_position; bool retired; const transit_station_catalog_snapshot *snapshot; bool released; transit_station_catalog_read_authority authority; } transit_station_catalog_snapshot_status_view;
typedef struct transit_station_catalog_snapshot_metadata_view { const transit_station_catalog_snapshot *snapshot; transit_station_catalog_stored interpretation; transit_station_catalog_position accepted; uint64_t changed_lsn, row_count; transit_station_catalog_schema schema; transit_station_catalog_read_authority authority; } transit_station_catalog_snapshot_metadata_view;

/* Restores copy bounded complete JSON, including its mandatory definition.
 * Exports and typed views borrow from their owner until it is destroyed. */
transit_sdk_error transit_station_catalog_basis_restore(transit_sdk_bytes, transit_station_catalog_basis **out);
transit_sdk_error transit_station_catalog_basis_export(const transit_station_catalog_basis *, transit_sdk_bytes *out);
transit_sdk_error transit_station_catalog_saved_intent_restore(transit_sdk_bytes, transit_station_catalog_saved_intent **out);
transit_sdk_error transit_station_catalog_saved_intent_export(const transit_station_catalog_saved_intent *, transit_sdk_bytes *out);
transit_sdk_error transit_station_catalog_reference_restore(transit_sdk_bytes, transit_station_catalog_reference **out);
transit_sdk_error transit_station_catalog_reference_export(const transit_station_catalog_reference *, transit_sdk_bytes *out);
transit_sdk_error transit_station_catalog_cursor_restore(transit_sdk_bytes, transit_station_catalog_cursor **out);
transit_sdk_error transit_station_catalog_cursor_export(const transit_station_catalog_cursor *, transit_sdk_bytes *out);
transit_sdk_error transit_station_catalog_snapshot_owner_restore(transit_sdk_bytes, transit_station_catalog_snapshot_owner **out);
transit_sdk_error transit_station_catalog_snapshot_owner_export(const transit_station_catalog_snapshot_owner *, transit_sdk_bytes *out);
transit_sdk_error transit_station_catalog_snapshot_acquisition_restore(transit_sdk_bytes, transit_station_catalog_snapshot_acquisition **out);
transit_sdk_error transit_station_catalog_snapshot_acquisition_export(const transit_station_catalog_snapshot_acquisition *, transit_sdk_bytes *out);
transit_sdk_error transit_station_catalog_snapshot_restore(transit_sdk_bytes, transit_station_catalog_snapshot **out);
transit_sdk_error transit_station_catalog_snapshot_export(const transit_station_catalog_snapshot *, transit_sdk_bytes *out);
void transit_station_catalog_basis_destroy(transit_station_catalog_basis *);
void transit_station_catalog_saved_intent_destroy(transit_station_catalog_saved_intent *);
void transit_station_catalog_reference_destroy(transit_station_catalog_reference *);
void transit_station_catalog_cursor_destroy(transit_station_catalog_cursor *);
void transit_station_catalog_snapshot_owner_destroy(transit_station_catalog_snapshot_owner *);
void transit_station_catalog_snapshot_acquisition_destroy(transit_station_catalog_snapshot_acquisition *);
void transit_station_catalog_snapshot_destroy(transit_station_catalog_snapshot *);
void transit_station_catalog_intent_destroy(transit_station_catalog_intent *);
void transit_station_catalog_compiled_destroy(transit_station_catalog_compiled *);
void transit_station_catalog_metadata_destroy(transit_station_catalog_metadata *);
void transit_station_catalog_namespace_page_destroy(transit_station_catalog_namespace_page *);
void transit_station_catalog_table_page_destroy(transit_station_catalog_table_page *);
void transit_station_catalog_observation_destroy(transit_station_catalog_observation *);
void transit_station_catalog_preview_destroy(transit_station_catalog_preview *);
void transit_station_catalog_snapshot_status_destroy(transit_station_catalog_snapshot_status *);
void transit_station_catalog_snapshot_metadata_destroy(transit_station_catalog_snapshot_metadata *);
transit_sdk_error transit_station_catalog_basis_get(const transit_station_catalog_basis *, const transit_station_catalog_basis_view **out);
transit_sdk_error transit_station_catalog_reference_get(const transit_station_catalog_reference *, const transit_station_catalog_reference_view **out);
transit_sdk_error transit_station_catalog_cursor_get(const transit_station_catalog_cursor *, const transit_station_catalog_cursor_view **out);
transit_sdk_error transit_station_catalog_snapshot_owner_get(const transit_station_catalog_snapshot_owner *, const transit_station_catalog_snapshot_owner_view **out);
transit_sdk_error transit_station_catalog_snapshot_acquisition_get(const transit_station_catalog_snapshot_acquisition *, const transit_station_catalog_snapshot_acquisition_view **out);
transit_sdk_error transit_station_catalog_snapshot_get(const transit_station_catalog_snapshot *, const transit_station_catalog_snapshot_view **out);
transit_sdk_error transit_station_catalog_intent_get(const transit_station_catalog_intent *, const transit_station_catalog_intent_view **out);
transit_sdk_error transit_station_catalog_metadata_get(const transit_station_catalog_metadata *, const transit_station_catalog_metadata_view **out);
transit_sdk_error transit_station_catalog_namespace_page_get(const transit_station_catalog_namespace_page *, const transit_station_catalog_namespace_page_view **out);
transit_sdk_error transit_station_catalog_table_page_get(const transit_station_catalog_table_page *, const transit_station_catalog_table_page_view **out);
transit_sdk_error transit_station_catalog_observation_get(const transit_station_catalog_observation *, const transit_station_catalog_observation_view **out);
transit_sdk_error transit_station_catalog_preview_get(const transit_station_catalog_preview *, const transit_station_catalog_preview_view **out);
transit_sdk_error transit_station_catalog_snapshot_status_get(const transit_station_catalog_snapshot_status *, const transit_station_catalog_snapshot_status_view **out);
transit_sdk_error transit_station_catalog_snapshot_metadata_get(const transit_station_catalog_snapshot_metadata *, const transit_station_catalog_snapshot_metadata_view **out);
transit_sdk_error transit_station_catalog_compiled_get(const transit_station_catalog_compiled *, const transit_station_catalog_intent **intent, const transit_station_catalog_saved_intent **saved);
/* One active call. Close joins; deferred POSIX cancellation remains masked
 * through output publication. Join users before destroying handles. Failures
 * clear output pointers. Input saved values remain intact on unknown outcomes. */
transit_sdk_error transit_station_catalog_open(const transit_sdk_config *, const transit_sdk_credential *, transit_station_catalog_connection, const char *service_url, transit_station_catalog_client **out);
transit_sdk_error transit_station_catalog_close(transit_station_catalog_client *);
void transit_station_catalog_client_destroy(transit_station_catalog_client *);
transit_sdk_error transit_station_catalog_capabilities_read(transit_station_catalog_client *, transit_station_catalog_capabilities *out);
transit_sdk_error transit_station_catalog_describe(transit_station_catalog_client *, transit_station_catalog_description *out);
transit_sdk_error transit_station_catalog_namespace_read(transit_station_catalog_client *, uint64_t id, bool *found, transit_station_catalog_namespace *out);
transit_sdk_error transit_station_catalog_namespaces(transit_station_catalog_client *, const transit_station_catalog_cursor *, transit_station_catalog_namespace_page **out);
transit_sdk_error transit_station_catalog_tables(transit_station_catalog_client *, uint64_t namespace_id, const transit_station_catalog_cursor *, transit_station_catalog_table_page **out);
transit_sdk_error transit_station_catalog_lookup(transit_station_catalog_client *, const char *name, uint64_t namespace_id, transit_station_catalog_metadata **out);
transit_sdk_error transit_station_catalog_compile_sql(transit_station_catalog_client *, const char *sql, transit_station_catalog_identity, const uint64_t *create_object, transit_station_catalog_dialect, transit_station_catalog_ingestion, transit_station_catalog_compiled **out);
transit_sdk_error transit_station_catalog_prepare(transit_station_catalog_client *, const transit_station_catalog_request *, transit_station_catalog_compiled **out);
transit_sdk_error transit_station_catalog_load(transit_station_catalog_client *, const transit_station_catalog_saved_intent *, transit_station_catalog_intent **out);
transit_sdk_error transit_station_catalog_forget(transit_station_catalog_client *, const transit_station_catalog_intent *);
transit_sdk_error transit_station_catalog_preview_read(transit_station_catalog_client *, const transit_station_catalog_intent *, transit_station_catalog_preview **out);
transit_sdk_error transit_station_catalog_stage(transit_station_catalog_client *, const transit_station_catalog_intent *, transit_station_catalog_reference **out);
transit_sdk_error transit_station_catalog_admit(transit_station_catalog_client *, const transit_station_catalog_reference *, transit_station_catalog_observation **out);
transit_sdk_error transit_station_catalog_inspect(transit_station_catalog_client *, const transit_station_catalog_reference *, transit_station_catalog_observation **out);
transit_sdk_error transit_station_catalog_execute(transit_station_catalog_client *, const transit_station_catalog_reference *, uint16_t steps, transit_station_catalog_observation **out);
transit_sdk_error transit_station_catalog_cancel(transit_station_catalog_client *, const transit_station_catalog_reference *, transit_station_catalog_observation **out);
transit_sdk_error transit_station_catalog_prepare_snapshot(const transit_station_catalog_metadata *, uint64_t operation, transit_station_catalog_snapshot_acquisition **out);
transit_sdk_error transit_station_catalog_acquire_snapshot(transit_station_catalog_client *, const transit_station_catalog_snapshot_acquisition *, transit_station_catalog_snapshot **out);
transit_sdk_error transit_station_catalog_snapshot_status_read(transit_station_catalog_client *, const transit_station_catalog_snapshot_owner *, transit_station_catalog_snapshot_status **out);
transit_sdk_error transit_station_catalog_snapshot_metadata_read(transit_station_catalog_client *, const transit_station_catalog_snapshot *, transit_station_catalog_snapshot_metadata **out);
transit_sdk_error transit_station_catalog_release_snapshot(transit_station_catalog_client *, const transit_station_catalog_snapshot *);
#ifdef __cplusplus
}
#endif
#endif
