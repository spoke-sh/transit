#ifndef TRANSIT_SDK_UNIFIED_QUERY_H
#define TRANSIT_SDK_UNIFIED_QUERY_H
#include <transit/station.h>
#ifdef __cplusplus
extern "C" {
#endif

/* Explicit v1 profile. Input pointers are borrowed only for the synchronous
 * operation. Native Zig validates semantics; these are language-owned types. */
typedef enum transit_station_unified_type {
    TRANSIT_UNIFIED_INT64, TRANSIT_UNIFIED_UINT64, TRANSIT_UNIFIED_FLOAT64,
    TRANSIT_UNIFIED_BOOLEAN, TRANSIT_UNIFIED_UTF8, TRANSIT_UNIFIED_BINARY
} transit_station_unified_type;
typedef enum transit_station_unified_state {
    TRANSIT_UNIFIED_MISSING, TRANSIT_UNIFIED_NULL, TRANSIT_UNIFIED_TYPE_ERROR,
    TRANSIT_UNIFIED_VALUE, TRANSIT_UNIFIED_CONFLICT
} transit_station_unified_state;
typedef struct transit_station_unified_scalar {
    transit_station_unified_type type;
    int64_t signed_value; uint64_t unsigned_value; double float_value;
    bool boolean; transit_sdk_bytes bytes;
} transit_station_unified_scalar;
typedef struct transit_station_unified_column { const char *name; transit_station_unified_type type; } transit_station_unified_column;
typedef struct transit_station_unified_decoder { uint8_t version; transit_station_unified_type type; } transit_station_unified_decoder;
typedef enum transit_station_unified_projection_mode {
    TRANSIT_UNIFIED_SCALAR, TRANSIT_UNIFIED_TEXT, TRANSIT_UNIFIED_ELEMENT_COUNTER, TRANSIT_UNIFIED_ELEMENT_REPLICA
} transit_station_unified_projection_mode;
typedef struct transit_station_unified_projection {
    transit_station_unified_column column;
    const char *const *path; size_t path_count;
    bool relative; transit_station_unified_projection_mode mode;
    uint16_t text_bytes, text_steps; /* Explicit budgets, normally 4096 each. */
} transit_station_unified_projection;
typedef enum transit_station_unified_source_kind { TRANSIT_UNIFIED_KV, TRANSIT_UNIFIED_TABLE, TRANSIT_UNIFIED_DOCUMENT } transit_station_unified_source_kind;
typedef struct transit_station_unified_source {
    transit_station_unified_source_kind kind;
    transit_sdk_resource resource;
    union {
        struct { transit_sdk_bytes prefix; transit_station_unified_decoder key, value; } kv;
        struct { uint32_t id; const char *names[2]; transit_station_unified_type value_type; } table;
        struct {
            transit_station_document_reference reference;
            const transit_station_unified_projection *projections; size_t projection_count;
            bool has_expansion; const char *const *expand; size_t expand_count;
        } document;
    } source;
} transit_station_unified_source;
typedef enum transit_station_unified_predicate_kind { TRANSIT_UNIFIED_ALL, TRANSIT_UNIFIED_IS_STATE, TRANSIT_UNIFIED_COMPARE, TRANSIT_UNIFIED_PROGRAM } transit_station_unified_predicate_kind;
typedef struct transit_station_unified_predicate_atom {
    transit_station_unified_predicate_kind kind; /* ALL, IS_STATE or COMPARE. */
    uint8_t column; transit_station_unified_state state;
    transit_station_comparison comparison; transit_station_unified_scalar value;
} transit_station_unified_predicate_atom;
/* Integer storage lets the C++ implementation reject unknown C input codes
 * before treating them as an instruction, without an invalid-enum load. */
typedef uint32_t transit_station_unified_instruction_kind;
enum {
    TRANSIT_UNIFIED_ATOM, TRANSIT_UNIFIED_NEGATE, TRANSIT_UNIFIED_CONJUNCTION, TRANSIT_UNIFIED_DISJUNCTION
};
typedef struct transit_station_unified_instruction {
    transit_station_unified_instruction_kind kind;
    transit_station_unified_predicate_atom atom; /* Used only for ATOM. */
} transit_station_unified_instruction;
typedef struct transit_station_unified_plan {
    const uint8_t *projection; size_t projection_count;
    bool has_limit; uint64_t limit;
    transit_station_aggregate aggregate;
    transit_station_unified_predicate_kind predicate;
    uint8_t column; transit_station_unified_state state;
    transit_station_comparison comparison; transit_station_unified_scalar value;
    /* Null names retain defaults; slots beyond projection_count must be null. */
    const char *output_names[8];
    /* PROGRAM borrows 1..64 postfix instructions through prepare_bundle.
     * Other predicate kinds require NULL/0. Programs cannot nest. */
    const transit_station_unified_instruction *instructions; size_t instruction_count;
} transit_station_unified_plan;
typedef struct transit_station_unified_budgets { uint64_t pages, segments, result_bytes; } transit_station_unified_budgets;
typedef struct transit_station_unified_bundle transit_station_unified_bundle;
typedef struct transit_station_unified_prepared transit_station_unified_prepared;
typedef struct transit_station_unified_cursor transit_station_unified_cursor;
typedef struct transit_station_unified_client transit_station_unified_client;
typedef struct transit_station_unified_page transit_station_unified_page;
typedef struct transit_station_unified_rows transit_station_unified_rows;
transit_sdk_error transit_station_unified_prepare_bundle(const transit_station_unified_source *, const transit_station_unified_plan *, transit_station_unified_budgets, const char *native_directory, transit_station_unified_bundle **out);
transit_sdk_error transit_station_unified_bundle_import(transit_sdk_bytes, transit_station_unified_bundle **out);
transit_sdk_error transit_station_unified_bundle_bytes(const transit_station_unified_bundle *, transit_sdk_bytes *out);
void transit_station_unified_bundle_destroy(transit_station_unified_bundle *);
/* Persist opaque prepared bytes before submission. Import does not dispatch;
 * current native validation occurs before sending. Never parse/re-encode them. */
transit_sdk_error transit_station_unified_prepared_import(transit_sdk_bytes, transit_station_unified_prepared **out);
transit_sdk_error transit_station_unified_prepared_bytes(const transit_station_unified_prepared *, transit_sdk_bytes *out);
void transit_station_unified_prepared_destroy(transit_station_unified_prepared *);
transit_sdk_error transit_station_unified_cursor_import(transit_sdk_bytes, transit_station_unified_cursor **out);
transit_sdk_error transit_station_unified_cursor_bytes(const transit_station_unified_cursor *, transit_sdk_bytes *out);
void transit_station_unified_cursor_destroy(transit_station_unified_cursor *);
typedef struct transit_station_unified_connection {
    transit_sdk_process source, requester;
    transit_sdk_resource resource, requests;
} transit_station_unified_connection;
typedef struct transit_station_unified_description {
    uint64_t resource_revision, policy_revision;
    transit_station_unified_budgets budgets;
    bool has_active; uint64_t active;
    size_t bundle_bytes, segment_bytes, batch_rows;
} transit_station_unified_description;
typedef enum transit_station_unified_inspection_kind { TRANSIT_UNIFIED_DESCRIPTION, TRANSIT_UNIFIED_TABLES, TRANSIT_UNIFIED_EXPLANATION } transit_station_unified_inspection_kind;
typedef enum transit_station_unified_inspection_operator { TRANSIT_UNIFIED_SCAN, TRANSIT_UNIFIED_FILTER, TRANSIT_UNIFIED_INPUT_LIMIT, TRANSIT_UNIFIED_PROJECT, TRANSIT_UNIFIED_COUNT, TRANSIT_UNIFIED_SUM, TRANSIT_UNIFIED_COUNT_VALUES } transit_station_unified_inspection_operator;
typedef struct transit_station_unified_inspected_column { char name[33]; transit_station_unified_type type; } transit_station_unified_inspected_column;
typedef struct transit_station_unified_source_description { transit_station_unified_inspected_column columns[8]; size_t column_count; } transit_station_unified_source_description;
typedef struct transit_station_unified_table_listing { char names[1][33]; size_t count; } transit_station_unified_table_listing;
typedef struct transit_station_unified_inspected_atom {
    transit_station_unified_predicate_kind kind;
    char column[33]; transit_station_unified_state state;
    transit_station_comparison comparison; transit_station_unified_type type;
} transit_station_unified_inspected_atom;
typedef struct transit_station_unified_inspected_instruction {
    transit_station_unified_instruction_kind kind;
    transit_station_unified_inspected_atom atom;
} transit_station_unified_inspected_instruction;
typedef struct transit_station_unified_explanation {
    transit_station_unified_inspection_operator operators[4]; size_t operator_count;
    transit_station_unified_predicate_kind predicate;
    char column[33]; transit_station_unified_state state;
    transit_station_comparison comparison; transit_station_unified_type type;
    char projection[8][33]; size_t projection_count;
    bool has_limit; uint64_t limit; transit_station_aggregate aggregate;
    transit_station_unified_source_description output;
    transit_station_unified_budgets budgets;
    /* PROGRAM owns its redacted atoms inline; no input/client pointers. */
    transit_station_unified_inspected_instruction instructions[64]; size_t instruction_count;
} transit_station_unified_explanation;
/* Entirely caller-owned, with no borrowed pointers or destroy operation.
 * Bounds describe one configured source, not a fixed-size realm catalog. */
typedef struct transit_station_unified_inspection {
    char name[33]; transit_sdk_resource resource; transit_station_unified_source_kind source_kind;
    uint8_t source_digest[32], schema_digest[32]; uint64_t resource_revision, policy_revision;
    transit_station_unified_inspection_kind kind;
    union { transit_station_unified_source_description description; transit_station_unified_table_listing tables; transit_station_unified_explanation explanation; } details;
} transit_station_unified_inspection;
/* No activation or writer ownership. One in-flight operation; close joins.
 * Join all caller threads before destroying any public owner. */
transit_sdk_error transit_station_unified_open(const transit_sdk_config *, const transit_sdk_credential *, transit_station_unified_connection, transit_station_unified_client **out);
transit_sdk_error transit_station_unified_close(transit_station_unified_client *);
void transit_station_unified_client_destroy(transit_station_unified_client *);
transit_sdk_error transit_station_unified_describe(transit_station_unified_client *, const transit_station_unified_source *, transit_station_unified_description *out);
/* Current scoped metadata; no snapshot, query admission or literal disclosure.
 * Name/SQL are bounded UTF-8 strings; output is zeroed on failure. */
transit_sdk_error transit_station_unified_inspect_sql(transit_station_unified_client *, const transit_station_unified_source *, const char *name, const char *sql, transit_station_unified_budgets, transit_station_unified_inspection *out);
/* NULL bindings select ordinary SQL; a non-NULL empty set selects a template
 * without placeholders. At most three values; all inputs borrow for this call.
 * On success out owns its bundle independently; failure leaves out NULL.
 * Compilation uses current source access and performs no upload or admission. */
typedef struct transit_station_unified_bindings { const transit_station_unified_scalar *values; size_t count; } transit_station_unified_bindings;
transit_sdk_error transit_station_unified_compile_sql(transit_station_unified_client *, const transit_station_unified_source *, const char *name, const char *sql, transit_station_unified_budgets, const transit_station_unified_bindings *, transit_station_unified_bundle **out);
transit_sdk_error transit_station_unified_prepare_next(transit_station_unified_client *, uint64_t namespace_id, const transit_station_unified_bundle *, transit_station_unified_prepared **out); /* NULL: inspect status, not completion. */
typedef enum transit_station_unified_control { TRANSIT_UNIFIED_CANCEL, TRANSIT_UNIFIED_RETIRE, TRANSIT_UNIFIED_COLLECT } transit_station_unified_control;
transit_sdk_error transit_station_unified_prepare_control(transit_station_unified_client *, transit_station_unified_control, uint64_t namespace_id, transit_station_unified_prepared **out);
/* Receipt is admission only. UNKNOWN_OUTCOME leaves prepared bytes unchanged. */
transit_sdk_error transit_station_unified_submit(transit_station_unified_client *, const transit_station_unified_prepared *, uint64_t *input_position);
typedef enum transit_station_unified_observed { TRANSIT_UNIFIED_PENDING, TRANSIT_UNIFIED_COMMITTED, TRANSIT_UNIFIED_REJECTED } transit_station_unified_observed;
typedef struct transit_station_unified_observation { transit_station_unified_observed state; char reason[257]; } transit_station_unified_observation;
transit_sdk_error transit_station_unified_observe(transit_station_unified_client *, uint64_t input_position, transit_station_unified_observation *out);
typedef enum transit_station_unified_phase {
    TRANSIT_UNIFIED_UPLOADING, TRANSIT_UNIFIED_SEALED, TRANSIT_UNIFIED_ADMITTED, TRANSIT_UNIFIED_COMPLETE,
    TRANSIT_UNIFIED_CANCELLED, TRANSIT_UNIFIED_DENIED, TRANSIT_UNIFIED_JOB_REJECTED, TRANSIT_UNIFIED_RETIRED
} transit_station_unified_phase;
/* Stable domain code and stage; counters retain their complete uint64 range. */
typedef struct transit_station_unified_failure {
    char code[33], stage[33], dimension[33]; uint64_t limit, observed;
} transit_station_unified_failure;
typedef struct transit_station_unified_status {
    bool found; transit_station_unified_phase phase; uint64_t correlation;
    uint8_t reference[72], manifest[72]; bool has_manifest, collected, has_failure;
    transit_station_unified_failure failure;
    transit_sdk_diagnostic diagnostic;
} transit_station_unified_status;
transit_sdk_error transit_station_unified_status_read(transit_station_unified_client *, uint64_t namespace_id, transit_station_unified_status *out);
typedef enum transit_station_unified_finished { TRANSIT_UNIFIED_SOURCE_END, TRANSIT_UNIFIED_LIMIT } transit_station_unified_finished;
typedef struct transit_station_unified_manifest {
    uint64_t job; transit_station_read_version source; transit_sdk_process requester;
    uint64_t correlation, policy_revision; uint8_t request[72];
    transit_station_unified_source_kind source_kind; transit_sdk_resource resource; uint64_t revision;
    uint8_t source_digest[32], schema_digest[32], plan_digest[32];
    uint64_t pages, scanned, selected, value_count, segments, rows, byte_count;
    bool has_sum; int64_t sum; transit_station_unified_finished finished; uint8_t chain[32];
} transit_station_unified_manifest;
typedef struct transit_station_unified_page_info {
    transit_station_unified_manifest manifest;
    uint64_t ordinal; uint8_t rows;
    transit_station_unified_column columns[8]; size_t column_count;
    transit_sdk_bytes ipc;
} transit_station_unified_page_info;
/* Output pages own IPC/names independently of the client. Info pointers borrow
 * the page until destroy. Cursors own bytes and are never bearer grants. */
transit_sdk_error transit_station_unified_page_read(transit_station_unified_client *, uint64_t namespace_id, const transit_station_unified_cursor *, transit_station_unified_page **out);
transit_sdk_error transit_station_unified_page_get(const transit_station_unified_page *, transit_station_unified_page_info *out);
transit_sdk_error transit_station_unified_page_next(const transit_station_unified_page *, transit_station_unified_cursor **out); /* NULL means verified complete coverage. */
void transit_station_unified_page_destroy(transit_station_unified_page *);
/* Standalone Arrow decoding establishes shape, not current access/completion.
 * Cell byte views borrow the rows owner until destroy. */
typedef struct transit_station_unified_cell {
    transit_station_unified_state state;
    transit_station_unified_scalar value;
    char actual_kind[17]; size_t alternative_count;
} transit_station_unified_cell;
typedef struct transit_station_unified_alternative {
    uint64_t counter, replica; transit_station_unified_cell cell;
} transit_station_unified_alternative;
transit_sdk_error transit_station_unified_decode_arrow(const transit_station_unified_column *, size_t column_count, transit_sdk_bytes ipc, uint8_t rows, const char *native_directory, transit_station_unified_rows **out);
transit_sdk_error transit_station_unified_rows_cell(const transit_station_unified_rows *, size_t row, size_t column, transit_station_unified_cell *out);
transit_sdk_error transit_station_unified_rows_alternative(const transit_station_unified_rows *, size_t row, size_t column, size_t alternative, transit_station_unified_alternative *out);
void transit_station_unified_rows_destroy(transit_station_unified_rows *);

#ifdef __cplusplus
}
#endif
#endif
