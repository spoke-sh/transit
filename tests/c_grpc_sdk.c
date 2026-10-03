#include "c_grpc_sdk.h"
#include <assert.h>
#include <string.h>
#define TRY(expression) do { transit_sdk_error error = (expression); if (error.kind != TRANSIT_SDK_OK) return error; } while (0)
static transit_sdk_bytes bytes(const char *value) { return (transit_sdk_bytes){(const uint8_t *)value, strlen(value)}; }
transit_sdk_error grpc_test_prepare(uint64_t resource, transit_sdk_bytes descriptor, transit_sdk_bytes body, uint64_t deadline, transit_station_grpc_request **out) {
    const uint8_t binary[] = {0,255};
    const transit_station_grpc_metadata fields[] = {
        {"x-tag", false, bytes("one"), NULL, 0}, {"x-tag", false, bytes("two"), NULL, 0},
        {"x-data-bin", false, {binary,2}, NULL,0}, {"authorization", true, {0}, "api",7}
    };
    transit_station_grpc_template request = {0};
    TRY(transit_station_grpc_method_bind(descriptor,"/test.Peer/Bidi",NULL,&request.method));
    assert(request.method.shape == TRANSIT_GRPC_BIDI);
    request.metadata = fields; request.metadata_count = 4;
    const transit_station_grpc_options options = {{72,resource},UINT64_MAX,7,deadline,1};
    const transit_sdk_bytes messages[] = {body,{0}};
    return transit_station_grpc_prepare(&request,messages,2,&options,NULL,out);
}
typedef struct message { bool reply, released; size_t size; uint8_t bytes[243]; transit_station_grpc_outcome outcome; transit_station_grpc_released acknowledgement; } message;
static transit_sdk_error encode(void *context, const void *value, uint8_t *out, size_t capacity, size_t *written) {
    (void)context; const message *input = value; assert(!input->reply && input->size <= capacity);
    memcpy(out, input->bytes, input->size); *written = input->size; return (transit_sdk_error){0};
}
static transit_sdk_error decode(void *context, transit_sdk_bytes value, void *out) {
    const grpc_test_context *owner = context; message *decoded = out; memset(decoded, 0, sizeof(*decoded));
    if (value.size >= 4 && !memcmp(value.data, "GRK1", 4)) {
        decoded->reply = decoded->released = true; return transit_station_grpc_decode_released(owner->peer.realm, value, NULL, &decoded->acknowledgement);
    }
    if (value.size >= 4 && (!memcmp(value.data, "GRR1", 4) || !memcmp(value.data, "GRF1", 4))) {
        decoded->reply = true; return transit_station_grpc_decode(owner->peer.realm, value, NULL, &decoded->outcome);
    }
    assert(value.size <= sizeof(decoded->bytes)); decoded->size = value.size; memcpy(decoded->bytes, value.data, value.size);
    return (transit_sdk_error){0};
}
transit_station_codec grpc_test_codec(grpc_test_context *context) {
    return (transit_station_codec){"test.grpc-control", 1, 243, sizeof(message), context, encode, decode, NULL};
}
static transit_station_key key(const char *name) { return (transit_station_key){bytes(name), transit_example_u64_codec()}; }
static transit_sdk_error handle(void *context, transit_station_turn *turn, const transit_station_incoming *input) {
    grpc_test_context *owner = context;
    transit_station_turn_release(owner->escaped); owner->escaped = turn; transit_station_turn_retain(turn);
    const message *value = input->value;
    const transit_station_key release_key = key("grpc-release-correlation");
    const transit_station_key followup_key = key("grpc-followup-correlation");
    if (input->kind == TRANSIT_INPUT_CAST && value->size == 8 && !memcmp(value->bytes, "followup", 8)) {
        uint64_t correlation = UINT64_MAX;
        transit_station_grpc_outcome wrong = owner->parent; wrong.resource.realm = 73;
        assert(transit_station_turn_grpc_retry(turn, owner->peer, &wrong, owner->request, &correlation).kind == TRANSIT_SDK_INVALID_ARGUMENT && correlation == 0);
        TRY(transit_station_turn_grpc_retry(turn, owner->peer, &owner->parent, owner->request, &correlation));
        TRY(transit_station_state_put(turn, &followup_key, &correlation)); owner->result = 5; return (transit_sdk_error){0};
    }
    if (input->kind == TRANSIT_INPUT_REPLY && value->reply && !value->released && value->outcome.rejected) {
        transit_station_value *saved = NULL; TRY(transit_station_state_find(turn, NULL, &followup_key, &saved)); assert(saved);
        const uint64_t correlation = *(const uint64_t *)transit_station_value_data(saved); transit_station_value_destroy(saved);
        TRY(transit_station_turn_require_reply(turn, owner->peer, correlation)); assert(value->outcome.rejection == TRANSIT_GRPC_DENIED);
        assert(strstr(value->outcome.diagnostic.json, "field_path") && strstr(value->outcome.diagnostic.json, "native_input") && strstr(value->outcome.diagnostic.json, "proposal"));
        const transit_station_key rejected = key("grpc-followup-denied");
        TRY(transit_station_state_put(turn, &rejected, &correlation)); owner->result = 6; return (transit_sdk_error){0};
    }
    if (input->kind == TRANSIT_INPUT_CAST && value->size == 7 && !memcmp(value->bytes, "dispose", 7)) {
        uint64_t correlation = UINT64_MAX;
        assert(transit_station_turn_grpc_release(turn, owner->peer, (transit_sdk_resource){73, owner->disposal.resource.resource}, owner->disposal.exchange, &correlation).kind == TRANSIT_SDK_INVALID_ARGUMENT && correlation == 0);
        TRY(transit_station_turn_grpc_release(turn, owner->peer, owner->disposal.resource, owner->disposal.exchange, &correlation));
        TRY(transit_station_state_put(turn, &release_key, &correlation)); owner->result = 3; return (transit_sdk_error){0};
    }
    if (input->kind == TRANSIT_INPUT_REPLY && value->released) {
        transit_station_value *saved = NULL; TRY(transit_station_state_find(turn, NULL, &release_key, &saved)); assert(saved);
        const uint64_t correlation = *(const uint64_t *)transit_station_value_data(saved); transit_station_value_destroy(saved);
        TRY(transit_station_turn_require_reply(turn, owner->peer, correlation));
        assert(value->acknowledgement.resource.realm == owner->disposal.resource.realm && value->acknowledgement.resource.resource == owner->disposal.resource.resource && value->acknowledgement.exchange == owner->disposal.exchange);
        const transit_station_key disposed = key("grpc-disposed");
        TRY(transit_station_state_put(turn, &disposed, &value->acknowledgement.exchange)); owner->result = 4; return (transit_sdk_error){0};
    }
    const transit_station_key correlation_key = key("grpc-correlation");
    transit_station_value *saved = NULL; TRY(transit_station_state_find(turn, NULL, &correlation_key, &saved));
    const bool found = saved != NULL; uint64_t correlation = found ? *(const uint64_t *)transit_station_value_data(saved) : 0;
    transit_station_value_destroy(saved);
    if (input->kind == TRANSIT_INPUT_CAST) {
        bool ready = found;
        if (!found) {
            TRY(transit_station_turn_grpc_stage(turn, owner->request, &ready));
            if (ready) {
                TRY(transit_station_turn_grpc_call(turn, owner->peer, owner->request, &correlation));
                TRY(transit_station_state_put(turn, &correlation_key, &correlation));
            }
        }
        owner->result = ready ? 1 : 0;
    } else {
        assert(input->kind == TRANSIT_INPUT_REPLY && found);
        TRY(transit_station_turn_require_reply(turn, owner->peer, correlation));
        assert(value->reply && !value->outcome.rejected && value->outcome.phase == TRANSIT_GRPC_OBSERVED && value->outcome.has_status && value->outcome.status == 0);
        const transit_station_key status = key("grpc-status"); const uint64_t code = 0;
        TRY(transit_station_state_put(turn, &status, &code)); owner->result = 2;
    }
    return (transit_sdk_error){0};
}
transit_station_handler grpc_test_handler(grpc_test_context *context) { return (transit_station_handler){context, NULL, handle, NULL, NULL}; }
