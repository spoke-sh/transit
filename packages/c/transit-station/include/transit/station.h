#ifndef TRANSIT_SDK_STATION_H
#define TRANSIT_SDK_STATION_H
#include <transit/client.h>
#ifdef __cplusplus
extern "C" {
#endif
typedef struct transit_station_runner transit_station_runner;
typedef struct transit_station_turn transit_station_turn;
typedef struct transit_station_value transit_station_value;
typedef struct transit_station_event transit_station_event;
typedef struct transit_station_mutation transit_station_mutation;
typedef struct transit_station_cursor transit_station_cursor;
typedef struct transit_station_page transit_station_page;
typedef struct transit_station_table transit_station_table;
typedef struct transit_station_row transit_station_row;
typedef struct transit_station_segment transit_station_segment;
typedef struct transit_station_http_request transit_station_http_request;
typedef struct transit_station_http_reader transit_station_http_reader;

/* Codec callbacks construct/destroy one max_align_t-aligned application object.
 * On decode failure the callback must leave no constructed object or allocation.
 * encode writes at most capacity bytes and returns the actual byte count. */
typedef struct transit_station_codec {
    const char *type_id;
    uint32_t version;
    size_t max_encoded_bytes, object_bytes;
    void *context;
    transit_sdk_error (*encode)(void *context, const void *value, uint8_t *out, size_t capacity, size_t *written);
    transit_sdk_error (*decode)(void *context, transit_sdk_bytes bytes, void *out);
    void (*destroy)(void *context, void *value);
} transit_station_codec;
typedef struct transit_station_key { transit_sdk_bytes name; transit_station_codec codec; } transit_station_key;
typedef enum transit_station_origin_kind { TRANSIT_ORIGIN_EXTERNAL, TRANSIT_ORIGIN_PROCESS, TRANSIT_ORIGIN_EFFECT } transit_station_origin_kind;
typedef struct transit_station_origin {
    transit_station_origin_kind kind;
    uint64_t principal, policy_revision;
    transit_sdk_process process;
    uint64_t turn, output, effect, attempt, executor;
} transit_station_origin;
typedef enum transit_station_input_kind { TRANSIT_INPUT_CAST, TRANSIT_INPUT_CALL, TRANSIT_INPUT_REPLY, TRANSIT_INPUT_CANCEL, TRANSIT_INPUT_TIMEOUT, TRANSIT_INPUT_RESULT_COMPLETE } transit_station_input_kind;
typedef struct transit_station_incoming {
    transit_station_input_kind kind;
    uint64_t position, correlation;
    transit_station_origin origin;
    const void *value; /* Borrowed decoded application object; NULL for controls/results. */
} transit_station_incoming;
typedef struct transit_station_handler {
    void *context;
    transit_sdk_error (*initialize)(void *context, transit_station_turn *turn);
    transit_sdk_error (*message)(void *context, transit_station_turn *turn, const transit_station_incoming *input);
    transit_sdk_error (*control)(void *context, transit_station_turn *turn, const transit_station_incoming *input);
    transit_sdk_error (*result)(void *context, transit_station_turn *turn, const transit_station_incoming *input);
} transit_station_handler;
typedef enum transit_station_failure_policy { TRANSIT_FAILURE_STOP, TRANSIT_FAILURE_BLOCK_INPUT } transit_station_failure_policy;
typedef enum transit_station_recovery_policy { TRANSIT_RECOVERY_FRESH_OWNERSHIP, TRANSIT_RECOVERY_PERSIST_BEFORE_DISPATCH } transit_station_recovery_policy;
typedef struct transit_station_options {
    transit_station_failure_policy failure;
    transit_station_recovery_policy recovery;
    void *context;
    transit_sdk_error (*before_dispatch)(void *context, const transit_station_mutation *mutation);
    transit_sdk_error (*confirmed)(void *context, const char *identity, transit_sdk_confirmation receipt);
} transit_station_options;
typedef struct transit_station_config {
    transit_sdk_config client;
    transit_sdk_process process;
    transit_sdk_credential credential;
    uint64_t generation;
    const char *association;
    bool query_results;
} transit_station_config;
typedef enum transit_station_purpose { TRANSIT_MUTATION_PERMIT, TRANSIT_MUTATION_OPEN, TRANSIT_MUTATION_COMMIT } transit_station_purpose;
typedef struct transit_station_mutation_info {
    transit_sdk_mutation_info operation;
    transit_station_purpose purpose;
    uint64_t input;
} transit_station_mutation_info;
typedef enum transit_station_event_kind { TRANSIT_EVENT_STOPPED, TRANSIT_EVENT_IDLE, TRANSIT_EVENT_PROGRESS, TRANSIT_EVENT_COMMITTED, TRANSIT_EVENT_BLOCKED, TRANSIT_EVENT_NEEDS_RECOVERY } transit_station_event_kind;
typedef struct transit_station_event_info {
    transit_station_event_kind kind;
    uint64_t input;
    bool has_receipt;
    transit_sdk_confirmation receipt;
    transit_sdk_error error;
    char phase[64];
} transit_station_event_info;
typedef struct transit_station_turn_info {
    transit_sdk_process process;
    transit_sdk_resource resource;
    uint64_t revision;
    bool initializing;
} transit_station_turn_info;
typedef struct transit_station_budgets { size_t mutations, outputs, views, retained_reads, retains, releases; } transit_station_budgets;
typedef struct transit_station_wait { bool timed; uint64_t deadline_ms, observer; } transit_station_wait;
typedef struct transit_station_read_version { uint64_t pid, input; uint8_t index; } transit_station_read_version;
typedef struct transit_station_basis { transit_sdk_resource resource; uint64_t revision; uint8_t schema[32]; } transit_station_basis;
typedef struct transit_station_kv_entry { transit_sdk_bytes key, value; uint64_t revision; } transit_station_kv_entry;

transit_sdk_error transit_station_runner_open(const transit_station_config *config, const transit_station_handler *handler, const transit_station_codec *codec, const transit_station_options *options, transit_station_runner **out);
transit_sdk_error transit_station_runner_next(transit_station_runner *runner, transit_station_event **out);
transit_sdk_error transit_station_runner_reconcile(transit_station_runner *runner, transit_station_event **out);
void transit_station_runner_stop(transit_station_runner *runner);
transit_sdk_error transit_station_runner_evidence(transit_station_runner *runner, transit_station_event **out);
transit_sdk_error transit_station_runner_close(transit_station_runner *runner, transit_station_event **out);
void transit_station_runner_destroy(transit_station_runner *runner);
transit_sdk_error transit_station_event_inspect(const transit_station_event *event, transit_station_event_info *out);
transit_sdk_error transit_station_event_pending(const transit_station_event *event, transit_station_mutation **out); /* NULL if none. */
void transit_station_event_destroy(transit_station_event *event);
transit_sdk_error transit_station_mutation_inspect(const transit_station_mutation *mutation, transit_station_mutation_info *out);
transit_sdk_error transit_station_mutation_export(const transit_station_mutation *mutation, transit_sdk_buffer *out);
void transit_station_mutation_destroy(transit_station_mutation *mutation);

/* Callbacks borrow a turn. Retain before keeping it; retained handles reject
 * use after the handler turn or from another thread and remain safe after close. */
void transit_station_turn_retain(transit_station_turn *turn);
void transit_station_turn_release(transit_station_turn *turn);
transit_sdk_error transit_station_turn_inspect(transit_station_turn *turn, transit_station_turn_info *out);
transit_sdk_error transit_station_turn_budgets(transit_station_turn *turn, transit_station_budgets *out);
transit_sdk_error transit_station_turn_cast(transit_station_turn *turn, transit_sdk_process peer, const void *value, const transit_station_codec *codec);
transit_sdk_error transit_station_turn_call(transit_station_turn *turn, transit_sdk_process peer, const void *value, const transit_station_codec *codec, transit_station_wait wait, uint64_t *correlation);
transit_sdk_error transit_station_turn_reply(transit_station_turn *turn, const void *value, const transit_station_codec *codec);
transit_sdk_error transit_station_turn_require_reply(transit_station_turn *turn, transit_sdk_process peer, uint64_t correlation);
transit_sdk_error transit_station_turn_cancel(transit_station_turn *turn, uint64_t correlation, bool *cancelled);
transit_sdk_error transit_station_encode_cast(const void *value, const transit_station_codec *codec, const char *native_directory, transit_sdk_buffer *out);

/* A NULL version selects this turn's mutable associated resource. Retained
 * versions are read-only and each access rechecks native authority. */
transit_sdk_error transit_station_state_find(transit_station_turn *turn, const transit_station_read_version *version, const transit_station_key *key, transit_station_value **out); /* NULL means missing. */
transit_sdk_error transit_station_state_put(transit_station_turn *turn, const transit_station_key *key, const void *value);
transit_sdk_error transit_station_state_delete(transit_station_turn *turn, const transit_station_key *key);
transit_sdk_error transit_station_state_page(transit_station_turn *turn, const transit_station_read_version *version, const transit_station_cursor *after, transit_station_page **out);
const void *transit_station_value_data(const transit_station_value *value);
void transit_station_value_destroy(transit_station_value *value);
transit_sdk_error transit_station_turn_retain_source(transit_station_turn *turn, transit_station_read_version *out);
transit_sdk_error transit_station_turn_release_source(transit_station_turn *turn, transit_station_read_version version);
transit_sdk_error transit_station_cursor_import(transit_sdk_bytes bytes, transit_station_cursor **out);
transit_sdk_error transit_station_cursor_export(const transit_station_cursor *cursor, transit_sdk_buffer *out);
void transit_station_cursor_destroy(transit_station_cursor *cursor);
size_t transit_station_page_size(const transit_station_page *page);
transit_sdk_error transit_station_page_next(const transit_station_page *page, transit_station_cursor **out);
transit_sdk_error transit_station_page_kv(const transit_station_page *page, size_t index, transit_station_kv_entry *out);
transit_sdk_error transit_station_page_basis(const transit_station_page *page, transit_station_basis *out);
void transit_station_page_destroy(transit_station_page *page);

typedef enum transit_station_cell_kind { TRANSIT_CELL_NULL, TRANSIT_CELL_INT64, TRANSIT_CELL_BOOLEAN, TRANSIT_CELL_UTF8, TRANSIT_CELL_BINARY } transit_station_cell_kind;
typedef struct transit_station_cell {
    transit_station_cell_kind kind;
    int64_t integer;
    bool boolean;
    transit_sdk_bytes bytes;
} transit_station_cell;
typedef struct transit_station_row_view { int64_t key; transit_station_cell value; } transit_station_row_view;
typedef struct transit_station_table_schema {
    uint32_t id;
    transit_station_cell_kind value_type;
    const char *key_name, *value_name;
} transit_station_table_schema;
typedef enum transit_station_write_mode { TRANSIT_WRITE_INSERT, TRANSIT_WRITE_UPDATE, TRANSIT_WRITE_UPSERT } transit_station_write_mode;
transit_sdk_error transit_station_table_open(transit_station_turn *turn, const transit_station_table_schema *schema, const transit_station_read_version *version, transit_station_table **out);
transit_sdk_error transit_station_table_create(transit_station_turn *turn, const transit_station_table_schema *schema, transit_station_table **out);
transit_sdk_error transit_station_table_basis(transit_station_table *table, transit_station_basis *out);
transit_sdk_error transit_station_table_get(transit_station_table *table, int64_t key, transit_station_row **out); /* NULL means missing. */
transit_sdk_error transit_station_table_write(transit_station_table *table, transit_station_write_mode mode, transit_station_row_view row);
transit_sdk_error transit_station_table_delete(transit_station_table *table, int64_t key);
transit_sdk_error transit_station_table_page(transit_station_table *table, const transit_station_cursor *after, transit_station_page **out);
transit_sdk_error transit_station_page_row(const transit_station_page *page, size_t index, transit_station_row_view *out);
transit_sdk_error transit_station_row_inspect(const transit_station_row *row, transit_station_row_view *out);
void transit_station_row_destroy(transit_station_row *row);
void transit_station_table_destroy(transit_station_table *table);

typedef enum transit_station_projection { TRANSIT_PROJECT_BOTH, TRANSIT_PROJECT_KEY, TRANSIT_PROJECT_VALUE } transit_station_projection;
typedef enum transit_station_aggregate { TRANSIT_AGGREGATE_ROWS, TRANSIT_AGGREGATE_COUNT, TRANSIT_AGGREGATE_SUM } transit_station_aggregate;
typedef enum transit_station_column { TRANSIT_COLUMN_KEY, TRANSIT_COLUMN_VALUE } transit_station_column;
typedef enum transit_station_comparison { TRANSIT_COMPARE_EQ, TRANSIT_COMPARE_NE, TRANSIT_COMPARE_LT, TRANSIT_COMPARE_LE, TRANSIT_COMPARE_GT, TRANSIT_COMPARE_GE } transit_station_comparison;
typedef enum transit_station_predicate_kind { TRANSIT_PREDICATE_ALL, TRANSIT_PREDICATE_NULL, TRANSIT_PREDICATE_COMPARE } transit_station_predicate_kind;
typedef struct transit_station_query_plan {
    transit_station_projection projection;
    transit_station_aggregate aggregate;
    bool has_limit;
    uint64_t limit;
    transit_station_predicate_kind predicate;
    transit_station_column column;
    transit_station_comparison comparison;
    transit_station_cell value;
} transit_station_query_plan;
typedef struct transit_station_query_job { uint64_t result, correlation; transit_station_read_version source; } transit_station_query_job;
typedef struct transit_station_manifest {
    uint64_t result;
    transit_sdk_process source, destination;
    uint64_t correlation;
    uint32_t table;
    uint64_t policy_revision;
    transit_station_basis basis;
    uint8_t plan[32];
    uint64_t segments, bytes, rows;
    uint8_t chain[32], schema[32];
} transit_station_manifest;
typedef struct transit_station_segment_info { transit_station_manifest manifest; uint64_t ordinal, rows; uint8_t digest[32]; } transit_station_segment_info;
typedef enum transit_station_query_close_reason { TRANSIT_QUERY_CANCELLED, TRANSIT_QUERY_DENIED } transit_station_query_close_reason;
transit_sdk_error transit_station_turn_allow_query(transit_station_turn *turn, transit_sdk_process peer, uint32_t table, uint64_t expected_revision, bool allow);
transit_sdk_error transit_station_table_start_query(transit_station_table *table, const transit_station_query_plan *plan, transit_station_query_job *out);
transit_sdk_error transit_station_turn_close_query(transit_station_turn *turn, uint64_t result, transit_station_query_close_reason reason);
transit_sdk_error transit_station_result_manifest(transit_station_turn *turn, uint64_t correlation, transit_station_manifest *out);
transit_sdk_error transit_station_result_segment(transit_station_turn *turn, uint64_t correlation, uint64_t ordinal, transit_station_segment **out);
transit_sdk_error transit_station_segment_inspect(const transit_station_segment *segment, transit_station_segment_info *out);
transit_sdk_error transit_station_segment_ipc(const transit_station_segment *segment, transit_sdk_buffer *out);
void transit_station_segment_destroy(transit_station_segment *segment);

/* HTTP inputs are borrowed through preparation; the prepared request owns its
 * reference/metadata/body. Secret values never enter these structures. */
typedef enum transit_station_http_method { TRANSIT_HTTP_GET, TRANSIT_HTTP_HEAD, TRANSIT_HTTP_POST, TRANSIT_HTTP_PUT, TRANSIT_HTTP_PATCH, TRANSIT_HTTP_DELETE, TRANSIT_HTTP_OPTIONS } transit_station_http_method;
typedef enum transit_station_http_piece_kind { TRANSIT_HTTP_LITERAL, TRANSIT_HTTP_VARIABLE, TRANSIT_HTTP_SECRET } transit_station_http_piece_kind;
typedef struct transit_station_http_piece {
    transit_station_http_piece_kind kind;
    transit_sdk_bytes name, value;
    uint64_t version;
} transit_station_http_piece;
typedef struct transit_station_http_header { const char *name; const transit_station_http_piece *pieces; size_t count; } transit_station_http_header;
typedef struct transit_station_http_template {
    transit_station_http_method method;
    const transit_station_http_piece *target;
    size_t target_count;
    const transit_station_http_header *headers;
    size_t header_count;
} transit_station_http_template;
typedef struct transit_station_http_options {
    transit_sdk_resource resource;
    uint64_t namespace_id, endpoint_revision, reconcile_before_ms;
    uint32_t max_attempts;
} transit_station_http_options;
typedef struct transit_station_http_request_view {
    transit_sdk_resource resource;
    uint64_t namespace_id;
    transit_sdk_bytes reference, metadata, body;
} transit_station_http_request_view;
typedef enum transit_station_http_phase { TRANSIT_HTTP_OBSERVED, TRANSIT_HTTP_CLOSED_UNKNOWN, TRANSIT_HTTP_NOT_DISPATCHED } transit_station_http_phase;
typedef enum transit_station_http_rejection { TRANSIT_HTTP_DENIED, TRANSIT_HTTP_INVALID_REQUEST, TRANSIT_HTTP_BUSY } transit_station_http_rejection;
/* Integer input keeps unknown values defined across the C/C++ boundary so they
 * can return INVALID_ARGUMENT instead of triggering an invalid enum load. */
typedef uint32_t transit_station_http_followup_reason;
enum { TRANSIT_HTTP_RETRY, TRANSIT_HTTP_REDIRECT, TRANSIT_HTTP_RECONCILE, TRANSIT_HTTP_CANCEL };
typedef struct transit_station_http_outcome {
    bool rejected;
    transit_station_http_rejection rejection;
    transit_station_http_phase phase;
    transit_sdk_resource resource;
    uint64_t exchange, effect, attempt;
    uint16_t status; /* Zero unless observed. HTTP status is not business success. */
    size_t reference_size; /* Zero unless complete; not a bearer grant. */
    uint8_t reference[256];
} transit_station_http_outcome;
typedef struct transit_station_http_released {
    transit_sdk_resource resource;
    uint64_t exchange;
} transit_station_http_released;
typedef enum transit_station_http_replay_policy { TRANSIT_HTTP_CAPTURED, TRANSIT_HTTP_REQUIRE_UNREDACTED } transit_station_http_replay_policy;
typedef enum transit_station_http_part_kind { TRANSIT_HTTP_REQUEST_TEMPLATE, TRANSIT_HTTP_REQUEST_HEAD, TRANSIT_HTTP_REQUEST_BODY, TRANSIT_HTTP_RESPONSE_HEAD, TRANSIT_HTTP_RESPONSE_BODY, TRANSIT_HTTP_RESPONSE_TRAILERS, TRANSIT_HTTP_TIMING, TRANSIT_HTTP_OMISSION, TRANSIT_HTTP_COMPLETION } transit_station_http_part_kind;
typedef struct transit_station_http_part {
    bool present, complete;
    transit_station_http_part_kind kind;
    size_t size;
    uint8_t bytes[256]; /* Owned inline bytes; arbitrary HTTP record boundaries. */
} transit_station_http_part;
transit_sdk_error transit_station_http_prepare(const transit_station_http_template *request, transit_sdk_bytes body, const transit_station_http_options *options, const char *native_directory, transit_station_http_request **out);
transit_sdk_error transit_station_http_request_inspect(const transit_station_http_request *request, transit_station_http_request_view *out);
void transit_station_http_request_destroy(transit_station_http_request *request);
transit_sdk_error transit_station_http_decode(uint64_t realm, transit_sdk_bytes bytes, const char *native_directory, transit_station_http_outcome *out);
transit_sdk_error transit_station_http_decode_released(uint64_t realm, transit_sdk_bytes bytes, const char *native_directory, transit_station_http_released *out);
transit_sdk_error transit_station_turn_http_stage(transit_station_turn *turn, const transit_station_http_request *request, bool *ready);
transit_sdk_error transit_station_turn_http_call(transit_station_turn *turn, transit_sdk_process peer, const transit_station_http_request *request, uint64_t *correlation);
/* Request durable hold disposal; authenticate the correlated HTK1 reply. */
transit_sdk_error transit_station_turn_http_release(transit_station_turn *turn, transit_sdk_process peer, transit_sdk_resource capture, uint64_t exchange, uint64_t *correlation);
/* Submit a linked attempt using an already published request; service policy
 * decides admission. Pointers remain borrowed for this synchronous operation. */
transit_sdk_error transit_station_turn_http_followup(transit_station_turn *turn, transit_sdk_process peer, const transit_station_http_outcome *parent, transit_station_http_followup_reason reason, const transit_station_http_request *request, uint64_t *correlation);
/* Reader retains local runner lifetime. Runner destroy/close joins native work;
 * caller must join concurrent uses before destroying any public handle. */
transit_sdk_error transit_station_http_open(transit_station_runner *runner, const transit_station_http_outcome *outcome, transit_station_http_replay_policy policy, transit_station_http_reader **out);
transit_sdk_error transit_station_http_read(transit_station_http_reader *reader, transit_station_http_part *out);
transit_sdk_error transit_station_http_close(transit_station_http_reader *reader);
void transit_station_http_reader_destroy(transit_station_http_reader *reader);
/* RPC values are caller-owned. The shared native implementation binds schemas,
 * constructs publication commitments, and verifies durable transcripts. */
typedef struct transit_station_grpc_request transit_station_grpc_request;
typedef struct transit_station_grpc_reader transit_station_grpc_reader;
typedef uint32_t transit_station_grpc_shape;
enum { TRANSIT_GRPC_UNARY, TRANSIT_GRPC_SERVER_STREAMING, TRANSIT_GRPC_CLIENT_STREAMING, TRANSIT_GRPC_BIDI };
typedef struct transit_station_grpc_method {
    char path[513];
    transit_station_grpc_shape shape;
    uint8_t descriptor_digest[32];
} transit_station_grpc_method;
typedef struct transit_station_grpc_metadata {
    const char *name;
    bool secret;
    transit_sdk_bytes bytes; /* Literal original bytes; -bin encoding belongs to Zig. */
    const char *binding;
    uint64_t version;
} transit_station_grpc_metadata;
typedef struct transit_station_grpc_template {
    transit_station_grpc_method method;
    const transit_station_grpc_metadata *metadata;
    size_t metadata_count;
} transit_station_grpc_template;
typedef struct transit_station_grpc_options {
    transit_sdk_resource resource;
    uint64_t namespace_id, endpoint_revision, reconcile_before_ms;
    uint32_t max_attempts;
} transit_station_grpc_options;
transit_sdk_error transit_station_grpc_method_bind(transit_sdk_bytes descriptor, const char *path, const char *native_directory, transit_station_grpc_method *out);
typedef struct transit_station_grpc_request_view {
    transit_sdk_resource resource;
    uint64_t namespace_id;
    transit_sdk_bytes reference, metadata, batch;
} transit_station_grpc_request_view;
typedef enum transit_station_grpc_phase { TRANSIT_GRPC_OBSERVED, TRANSIT_GRPC_CLOSED_UNKNOWN, TRANSIT_GRPC_NOT_DISPATCHED } transit_station_grpc_phase;
typedef enum transit_station_grpc_rejection { TRANSIT_GRPC_DENIED, TRANSIT_GRPC_INVALID_REQUEST, TRANSIT_GRPC_BUSY } transit_station_grpc_rejection;
typedef struct transit_station_grpc_outcome {
    bool rejected;
    transit_station_grpc_rejection rejection;
    transit_station_grpc_phase phase;
    transit_sdk_resource resource;
    uint64_t exchange, effect, attempt;
    uint32_t status; /* Meaningful only when has_status is true; zero means OK. */
    bool has_status;
    size_t reference_size; /* Zero unless complete; not a bearer grant. */
    uint8_t reference[256];
} transit_station_grpc_outcome;
typedef struct transit_station_grpc_released {
    transit_sdk_resource resource;
    uint64_t exchange;
} transit_station_grpc_released;
typedef enum transit_station_grpc_replay_policy { TRANSIT_GRPC_CAPTURED, TRANSIT_GRPC_REQUIRE_UNREDACTED } transit_station_grpc_replay_policy;
typedef enum transit_station_grpc_part_kind { TRANSIT_GRPC_REQUEST_METADATA, TRANSIT_GRPC_REQUEST_BATCH, TRANSIT_GRPC_ENDPOINT_POLICY, TRANSIT_GRPC_INITIAL_METADATA, TRANSIT_GRPC_RESPONSE_MESSAGE, TRANSIT_GRPC_RESPONSE_BODY, TRANSIT_GRPC_HALF_CLOSE, TRANSIT_GRPC_TRAILERS, TRANSIT_GRPC_TIMING, TRANSIT_GRPC_OMISSION, TRANSIT_GRPC_COMPLETION } transit_station_grpc_part_kind;
typedef struct transit_station_grpc_part {
    bool present, complete;
    transit_station_grpc_part_kind kind;
    size_t size;
    uint8_t bytes[256]; /* Owned inline bytes; arbitrary GRPC record boundaries. */
} transit_station_grpc_part;
transit_sdk_error transit_station_grpc_prepare(const transit_station_grpc_template *request, const transit_sdk_bytes *messages, size_t message_count, const transit_station_grpc_options *options, const char *native_directory, transit_station_grpc_request **out);
transit_sdk_error transit_station_grpc_request_inspect(const transit_station_grpc_request *request, transit_station_grpc_request_view *out);
void transit_station_grpc_request_destroy(transit_station_grpc_request *request);
transit_sdk_error transit_station_grpc_decode(uint64_t realm, transit_sdk_bytes bytes, const char *native_directory, transit_station_grpc_outcome *out);
transit_sdk_error transit_station_grpc_decode_released(uint64_t realm, transit_sdk_bytes bytes, const char *native_directory, transit_station_grpc_released *out);
transit_sdk_error transit_station_turn_grpc_stage(transit_station_turn *turn, const transit_station_grpc_request *request, bool *ready);
transit_sdk_error transit_station_turn_grpc_call(transit_station_turn *turn, transit_sdk_process peer, const transit_station_grpc_request *request, uint64_t *correlation);
/* Request durable hold disposal; authenticate the correlated GRK1 reply. */
transit_sdk_error transit_station_turn_grpc_release(transit_station_turn *turn, transit_sdk_process peer, transit_sdk_resource capture, uint64_t exchange, uint64_t *correlation);
/* Submit a linked attempt using an already published request; service policy
 * decides admission. Pointers remain borrowed for this synchronous operation. */
transit_sdk_error transit_station_turn_grpc_retry(transit_station_turn *turn, transit_sdk_process peer, const transit_station_grpc_outcome *parent, const transit_station_grpc_request *request, uint64_t *correlation);
/* Reader retains local runner lifetime. Runner destroy/close joins native work;
 * caller must join concurrent uses before destroying any public handle. */
transit_sdk_error transit_station_grpc_open(transit_station_runner *runner, const transit_station_grpc_outcome *outcome, transit_station_grpc_replay_policy policy, transit_station_grpc_reader **out);
transit_sdk_error transit_station_grpc_read(transit_station_grpc_reader *reader, transit_station_grpc_part *out);
transit_sdk_error transit_station_grpc_close(transit_station_grpc_reader *reader);
void transit_station_grpc_reader_destroy(transit_station_grpc_reader *reader);
/* M17 bounded, owned Document values. Text positions are stable dots, not byte
 * offsets. Unused array tails are zeroed. No returned pointer borrows native I/O. */
typedef struct transit_station_document_dot { uint64_t counter, replica; } transit_station_document_dot;
typedef enum transit_station_document_value_kind {
    TRANSIT_DOCUMENT_NULL, TRANSIT_DOCUMENT_BOOLEAN, TRANSIT_DOCUMENT_SIGNED,
    TRANSIT_DOCUMENT_UNSIGNED, TRANSIT_DOCUMENT_FLOAT, TRANSIT_DOCUMENT_STRING,
    TRANSIT_DOCUMENT_BINARY, TRANSIT_DOCUMENT_MAP, TRANSIT_DOCUMENT_LIST,
    TRANSIT_DOCUMENT_TEXT, TRANSIT_DOCUMENT_CHARACTER
} transit_station_document_value_kind;
typedef struct transit_station_document_value {
    transit_station_document_value_kind kind;
    bool boolean; int64_t signed_value; uint64_t unsigned_value; double float_value;
    uint8_t bytes[96]; size_t size; /* UTF-8 for string/character; original binary. */
} transit_station_document_value;
typedef enum transit_station_document_operation_kind {
    TRANSIT_DOCUMENT_ASSIGN, TRANSIT_DOCUMENT_REMOVE, TRANSIT_DOCUMENT_INSERT,
    TRANSIT_DOCUMENT_SET_ELEMENT, TRANSIT_DOCUMENT_DELETE_ELEMENT
} transit_station_document_operation_kind;
typedef struct transit_station_document_operation {
    transit_station_document_operation_kind kind;
    transit_station_document_dot object, anchor; /* predecessor or target element */
    uint8_t field[64]; size_t field_size;
    transit_station_document_dot observed[8]; size_t observed_count;
    transit_station_document_value value;
} transit_station_document_operation;
typedef struct transit_station_document_change {
    uint64_t document, epoch; uint32_t type_revision;
    uint64_t replica, previous, first;
    transit_station_document_operation operations[8]; size_t operation_count;
} transit_station_document_change;
typedef struct transit_station_document_prepared transit_station_document_prepared;
transit_sdk_error transit_station_document_prepare(const transit_station_document_change *, const char *native_directory, transit_station_document_prepared **out);
transit_sdk_error transit_station_document_prepared_bytes(const transit_station_document_prepared *, transit_sdk_bytes *out); /* borrowed until destroy */
void transit_station_document_prepared_destroy(transit_station_document_prepared *);
transit_sdk_error transit_station_document_decode(transit_sdk_bytes, const char *native_directory, transit_station_document_change *out);
typedef struct transit_station_document_reference {
    transit_sdk_resource resource;
    uint64_t document, epoch; uint32_t type_revision; uint64_t revision;
} transit_station_document_reference;
transit_sdk_error transit_station_document_reference_encode(const transit_station_document_reference *, const char *native_directory, uint8_t out[40]);
transit_sdk_error transit_station_document_reference_decode(uint64_t realm, transit_sdk_bytes, const char *native_directory, transit_station_document_reference *out);
typedef struct transit_station_document_limits { uint32_t record_bytes; uint64_t staging_bytes; uint32_t staging_records; } transit_station_document_limits;
typedef enum transit_station_document_phase { TRANSIT_DOCUMENT_PROGRESS, TRANSIT_DOCUMENT_ACCEPTED, TRANSIT_DOCUMENT_DUPLICATE, TRANSIT_DOCUMENT_CHECKPOINT_COMPLETE } transit_station_document_phase;
typedef struct transit_station_document_progress { transit_station_document_phase phase; bool has_revision; uint64_t revision; } transit_station_document_progress;
/* Every owner operation borrows the handler turn and remains private until commit. */
transit_sdk_error transit_station_turn_document_create(transit_station_turn *, uint64_t document, uint32_t type_revision, transit_station_document_limits);
transit_sdk_error transit_station_turn_document_stage(transit_station_turn *, uint64_t document, uint64_t job, const transit_station_document_prepared *, uint32_t node_limit, transit_station_document_progress *out);
transit_sdk_error transit_station_turn_document_checkpoint(transit_station_turn *, uint64_t document, uint64_t job, transit_station_document_progress *out);
transit_sdk_error transit_station_turn_document_merge_window(transit_station_turn *, uint64_t document, uint64_t revisions);
transit_sdk_error transit_station_turn_document_reject(transit_station_turn *, uint64_t document, uint64_t job, bool checkpoint);
transit_sdk_error transit_station_turn_document_collect(transit_station_turn *, uint64_t document, uint64_t job, bool checkpoint, bool retired, bool *done);
transit_sdk_error transit_station_turn_document_retire(transit_station_turn *, uint64_t document);
typedef enum transit_station_document_status { TRANSIT_DOCUMENT_MISSING, TRANSIT_DOCUMENT_NULL_VALUE, TRANSIT_DOCUMENT_SCALAR, TRANSIT_DOCUMENT_OBJECT, TRANSIT_DOCUMENT_CONFLICT } transit_station_document_status;
typedef struct transit_station_document_assignment { transit_station_document_dot id; transit_station_document_value value; } transit_station_document_assignment;
typedef struct transit_station_document_field {
    transit_station_document_status status;
    transit_station_document_assignment assignments[8]; size_t count;
} transit_station_document_field;
typedef struct transit_station_document_description {
    transit_station_document_reference reference;
    uint64_t source_revision, floor, merge_window, active_job; bool retired; uint32_t change_format;
} transit_station_document_description;
typedef struct transit_station_document_path {
    transit_station_document_reference reference; uint64_t source_revision;
    transit_station_document_field field;
} transit_station_document_path;
typedef struct transit_station_document_item { transit_station_document_dot id; transit_station_document_field field; } transit_station_document_item;
typedef struct transit_station_document_page {
    transit_station_document_reference reference; uint64_t source_revision;
    transit_station_document_item items[8]; size_t count;
    char next[1025]; bool has_next;
} transit_station_document_page;
typedef struct transit_station_document_resynchronization {
    transit_station_document_reference reference; uint64_t floor, replica, previous_counter, clock;
} transit_station_document_resynchronization;
/* A reader retains a local runner handle. Runner destruction joins active work;
 * subsequent reader calls fail CLOSED. Each call rechecks current read policy. */
typedef struct transit_station_document_reader transit_station_document_reader;
transit_sdk_error transit_station_documents_open(transit_station_runner *, transit_station_document_reader **out);
void transit_station_document_reader_destroy(transit_station_document_reader *);
transit_sdk_error transit_station_document_describe(transit_station_document_reader *, transit_sdk_resource, uint64_t document, transit_station_document_description *out);
transit_sdk_error transit_station_document_path_read(transit_station_document_reader *, const transit_station_document_reference *, const transit_sdk_bytes *names, size_t name_count, transit_station_document_path *out);
transit_sdk_error transit_station_document_sequence(transit_station_document_reader *, const transit_station_document_reference *, transit_station_document_dot object, const char *cursor, transit_station_document_page *out);
transit_sdk_error transit_station_document_resynchronize(transit_station_document_reader *, transit_sdk_resource, uint64_t document, uint64_t replica, transit_station_document_resynchronization *out);
transit_sdk_error transit_station_document_accepted_change(transit_station_document_reader *, const transit_station_document_reference *, transit_station_document_change *out);

#ifdef __cplusplus
}
#endif
#endif
