#include <transit/sdk_examples.h>
#define TRY(expression) do { const transit_sdk_error problem = (expression); if (problem.kind != TRANSIT_SDK_OK) return problem; } while (0)
static transit_sdk_error unexpected(void) { transit_sdk_error error = {0}; error.kind = TRANSIT_SDK_HANDLER_ERROR; return error; }
transit_station_key transit_example_total_key(void) { return (transit_station_key){{(const uint8_t *)"total", 5}, transit_example_u64_codec()}; }
transit_station_key transit_example_request_key(void) { return (transit_station_key){{(const uint8_t *)"request", 7}, transit_example_u64_codec()}; }
transit_station_key transit_example_observed_key(void) { return (transit_station_key){{(const uint8_t *)"observed", 8}, transit_example_u64_codec()}; }
transit_station_table_schema transit_example_table(void) { return (transit_station_table_schema){1, TRANSIT_CELL_INT64, "id", "value"}; }
static transit_sdk_error required(transit_station_turn *turn, const transit_station_key *key, uint64_t *out) {
    transit_station_value *value = NULL; TRY(transit_station_state_find(turn, NULL, key, &value));
    if (!value) { transit_sdk_error error = {0}; error.kind = TRANSIT_SDK_MISSING_VALUE; return error; }
    *out = *(const uint64_t *)transit_station_value_data(value); transit_station_value_destroy(value); return (transit_sdk_error){0};
}
static transit_sdk_error initialize_counter(void *context, transit_station_turn *turn) {
    (void)context; const transit_station_key key = transit_example_total_key(); const uint64_t zero = 0; return transit_station_state_put(turn, &key, &zero);
}
static transit_sdk_error counter(void *context, transit_station_turn *turn, const transit_station_incoming *input) {
    (void)context; const transit_counter_message *message = input->value; const transit_station_key key = transit_example_total_key(); uint64_t total;
    if (input->kind == TRANSIT_INPUT_CAST && message->tag == TRANSIT_COUNTER_ADD) {
        TRY(required(turn, &key, &total)); if (UINT64_MAX - total < message->value) return unexpected(); total += message->value; return transit_station_state_put(turn, &key, &total);
    }
    if (input->kind == TRANSIT_INPUT_CALL && message->tag == TRANSIT_COUNTER_READ) {
        TRY(required(turn, &key, &total)); const transit_counter_message reply = {TRANSIT_COUNTER_TOTAL, total}; const transit_station_codec codec = transit_example_total_codec(); return transit_station_turn_reply(turn, &reply, &codec);
    }
    return unexpected();
}
static transit_sdk_error requester(void *context, transit_station_turn *turn, const transit_station_incoming *input) {
    const transit_example_peer *peer = context; const transit_counter_message *message = input->value; const transit_station_key request = transit_example_request_key();
    if (input->kind == TRANSIT_INPUT_CAST && message->tag == TRANSIT_COUNTER_START) {
        transit_station_value *saved = NULL; TRY(transit_station_state_find(turn, NULL, &request, &saved));
        if (saved) { transit_station_value_destroy(saved); return unexpected(); }
        const transit_counter_message call = {TRANSIT_COUNTER_READ, 0}; const transit_station_codec codec = transit_example_counter_codec(); uint64_t correlation;
        TRY(transit_station_turn_call(turn, peer->peer, &call, &codec, (transit_station_wait){0}, &correlation)); return transit_station_state_put(turn, &request, &correlation);
    }
    if (input->kind == TRANSIT_INPUT_REPLY && message->tag == TRANSIT_COUNTER_TOTAL) {
        uint64_t correlation; TRY(required(turn, &request, &correlation)); TRY(transit_station_turn_require_reply(turn, peer->peer, correlation));
        const transit_station_key observed = transit_example_observed_key(); return transit_station_state_put(turn, &observed, &message->value);
    }
    return unexpected();
}
static transit_sdk_error initialize_table(void *context, transit_station_turn *turn) {
    const transit_example_peer *peer = context; const transit_station_table_schema schema = transit_example_table(); transit_station_table *table = NULL;
    TRY(transit_station_table_create(turn, &schema, &table)); transit_station_table_destroy(table); return transit_station_turn_allow_query(turn, peer->peer, schema.id, 0, true);
}
static transit_sdk_error table_service(void *context, transit_station_turn *turn, const transit_station_incoming *input) {
    (void)context; const transit_query_message *message = input->value;
    if (input->kind == TRANSIT_INPUT_CAST && message->tag == TRANSIT_QUERY_INITIALIZE) return (transit_sdk_error){0};
    const transit_station_table_schema schema = transit_example_table(); transit_station_table *table = NULL;
    TRY(transit_station_table_open(turn, &schema, NULL, &table)); transit_sdk_error error;
    if (input->kind == TRANSIT_INPUT_CAST && message->tag == TRANSIT_QUERY_INSERT) {
        transit_station_row_view row = {0}; row.key = message->key; row.value.kind = message->has_value ? TRANSIT_CELL_INT64 : TRANSIT_CELL_NULL; row.value.integer = message->value;
        error = transit_station_table_write(table, TRANSIT_WRITE_INSERT, row);
    } else if (input->kind == TRANSIT_INPUT_CALL && message->tag == TRANSIT_QUERY_ROWS) {
        transit_station_query_plan plan = {0}; plan.has_limit = true; plan.limit = UINT64_MAX; transit_station_query_job job;
        error = transit_station_table_start_query(table, &plan, &job);
    } else error = unexpected();
    transit_station_table_destroy(table); return error;
}
static transit_sdk_error query_start(void *context, transit_station_turn *turn, const transit_station_incoming *input) {
    const transit_example_query_requester *requester = context; const transit_query_message *message = input->value;
    if (input->kind != TRANSIT_INPUT_CAST || message->tag != TRANSIT_QUERY_START) return unexpected();
    const transit_station_key request = transit_example_request_key(); transit_station_value *saved = NULL;
    TRY(transit_station_state_find(turn, NULL, &request, &saved)); if (saved) { transit_station_value_destroy(saved); return unexpected(); }
    const transit_query_message call = {TRANSIT_QUERY_ROWS, 0, false, 0}; const transit_station_codec codec = transit_example_query_codec(); uint64_t correlation;
    TRY(transit_station_turn_call(turn, requester->source, &call, &codec, (transit_station_wait){0}, &correlation)); return transit_station_state_put(turn, &request, &correlation);
}
static transit_sdk_error query_result(void *context, transit_station_turn *turn, const transit_station_incoming *input) {
    const transit_example_query_requester *requester = context; const transit_station_key request = transit_example_request_key(); uint64_t saved;
    TRY(required(turn, &request, &saved)); transit_station_manifest manifest; TRY(transit_station_result_manifest(turn, input->correlation, &manifest));
    if (saved != manifest.correlation || manifest.source.pid != requester->source.pid || manifest.source.realm != requester->source.realm || !requester->consume) return unexpected();
    for (uint64_t ordinal = 0; ordinal < manifest.segments; ++ordinal) {
        transit_station_segment *segment = NULL; TRY(transit_station_result_segment(turn, input->correlation, ordinal, &segment));
        const transit_sdk_error error = requester->consume(requester->context, segment); transit_station_segment_destroy(segment); if (error.kind != TRANSIT_SDK_OK) return error;
    }
    const transit_station_key observed = transit_example_observed_key(); return transit_station_state_put(turn, &observed, &manifest.rows);
}
transit_station_handler transit_example_counter_handler(void) { return (transit_station_handler){NULL, initialize_counter, counter, NULL, NULL}; }
transit_station_handler transit_example_requester_handler(transit_example_peer *context) { return (transit_station_handler){context, NULL, requester, NULL, NULL}; }
transit_station_handler transit_example_table_handler(transit_example_peer *context) { return (transit_station_handler){context, initialize_table, table_service, NULL, NULL}; }
transit_station_handler transit_example_query_requester_handler(transit_example_query_requester *context) { return (transit_station_handler){context, NULL, query_start, NULL, query_result}; }
