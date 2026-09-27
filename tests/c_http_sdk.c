#include "c_http_sdk.h"
#include <assert.h>
#include <string.h>
#define TRY(expression) do { transit_sdk_error error = (expression); if (error.kind != TRANSIT_SDK_OK) return error; } while (0)
static transit_sdk_bytes bytes(const char *value) { return (transit_sdk_bytes){(const uint8_t *)value, strlen(value)}; }
static transit_station_http_piece literal(const char *value) { return (transit_station_http_piece){TRANSIT_HTTP_LITERAL, {0}, bytes(value), 0}; }
transit_sdk_error http_test_prepare(uint64_t resource, transit_sdk_bytes body, uint64_t deadline, bool rich, transit_station_http_request **out) {
    const transit_station_http_piece target[] = {literal(rich ? "/items/" : "/write"), {TRANSIT_HTTP_VARIABLE, bytes("id"), bytes("λ /"), 0}};
    const transit_station_http_piece one[] = {literal("one")}, two[] = {literal("two")};
    const transit_station_http_piece credential[] = {literal("Bearer "), {TRANSIT_HTTP_SECRET, bytes("api"), {0}, 7}};
    const transit_station_http_header headers[] = {{"X-Tag", one, 1}, {"X-Tag", two, 1}, {"Authorization", credential, 2}};
    const transit_station_http_template request = {TRANSIT_HTTP_POST, target, rich ? 2 : 1, headers, rich ? 3 : 0};
    const transit_station_http_options options = {{72, resource}, UINT64_MAX, 7, deadline, rich ? 1 : 2};
    return transit_station_http_prepare(&request, body, &options, NULL, out);
}
typedef struct message { bool reply, released; size_t size; uint8_t bytes[243]; transit_station_http_outcome outcome; transit_station_http_released acknowledgement; } message;
static transit_sdk_error encode(void *context, const void *value, uint8_t *out, size_t capacity, size_t *written) {
    (void)context; const message *input = value; assert(!input->reply && input->size <= capacity);
    memcpy(out, input->bytes, input->size); *written = input->size; return (transit_sdk_error){0};
}
static transit_sdk_error decode(void *context, transit_sdk_bytes value, void *out) {
    const http_test_context *owner = context; message *decoded = out; memset(decoded, 0, sizeof(*decoded));
    if (value.size >= 4 && !memcmp(value.data, "HTK1", 4)) {
        decoded->reply = decoded->released = true; return transit_station_http_decode_released(owner->peer.realm, value, NULL, &decoded->acknowledgement);
    }
    if (value.size >= 4 && (!memcmp(value.data, "HTR1", 4) || !memcmp(value.data, "HTF1", 4))) {
        decoded->reply = true; return transit_station_http_decode(owner->peer.realm, value, NULL, &decoded->outcome);
    }
    assert(value.size <= sizeof(decoded->bytes)); decoded->size = value.size; memcpy(decoded->bytes, value.data, value.size);
    return (transit_sdk_error){0};
}
transit_station_codec http_test_codec(http_test_context *context) {
    return (transit_station_codec){"test.http-control", 1, 243, sizeof(message), context, encode, decode, NULL};
}
static transit_station_key key(const char *name) { return (transit_station_key){bytes(name), transit_example_u64_codec()}; }
static transit_sdk_error handle(void *context, transit_station_turn *turn, const transit_station_incoming *input) {
    http_test_context *owner = context;
    transit_station_turn_release(owner->escaped); owner->escaped = turn; transit_station_turn_retain(turn);
    const message *value = input->value;
    const transit_station_key release_key = key("http-release-correlation");
    if (input->kind == TRANSIT_INPUT_CAST && value->size == 7 && !memcmp(value->bytes, "dispose", 7)) {
        uint64_t correlation = UINT64_MAX;
        assert(transit_station_turn_http_release(turn, owner->peer, (transit_sdk_resource){73, owner->disposal.resource.resource}, owner->disposal.exchange, &correlation).kind == TRANSIT_SDK_INVALID_ARGUMENT && correlation == 0);
        TRY(transit_station_turn_http_release(turn, owner->peer, owner->disposal.resource, owner->disposal.exchange, &correlation));
        TRY(transit_station_state_put(turn, &release_key, &correlation)); owner->result = 3; return (transit_sdk_error){0};
    }
    if (input->kind == TRANSIT_INPUT_REPLY && value->released) {
        transit_station_value *saved = NULL; TRY(transit_station_state_find(turn, NULL, &release_key, &saved)); assert(saved);
        const uint64_t correlation = *(const uint64_t *)transit_station_value_data(saved); transit_station_value_destroy(saved);
        TRY(transit_station_turn_require_reply(turn, owner->peer, correlation));
        assert(value->acknowledgement.resource.realm == owner->disposal.resource.realm && value->acknowledgement.resource.resource == owner->disposal.resource.resource && value->acknowledgement.exchange == owner->disposal.exchange);
        const transit_station_key disposed = key("http-disposed");
        TRY(transit_station_state_put(turn, &disposed, &value->acknowledgement.exchange)); owner->result = 4; return (transit_sdk_error){0};
    }
    const transit_station_key correlation_key = key("http-correlation");
    transit_station_value *saved = NULL; TRY(transit_station_state_find(turn, NULL, &correlation_key, &saved));
    const bool found = saved != NULL; uint64_t correlation = found ? *(const uint64_t *)transit_station_value_data(saved) : 0;
    transit_station_value_destroy(saved);
    if (input->kind == TRANSIT_INPUT_CAST) {
        bool ready = found;
        if (!found) {
            TRY(transit_station_turn_http_stage(turn, owner->request, &ready));
            if (ready) {
                TRY(transit_station_turn_http_call(turn, owner->peer, owner->request, &correlation));
                TRY(transit_station_state_put(turn, &correlation_key, &correlation));
            }
        }
        owner->result = ready ? 1 : 0;
    } else {
        assert(input->kind == TRANSIT_INPUT_REPLY && found);
        TRY(transit_station_turn_require_reply(turn, owner->peer, correlation));
        assert(value->reply && !value->outcome.rejected && value->outcome.phase == TRANSIT_HTTP_OBSERVED && value->outcome.status == 200);
        const transit_station_key status = key("http-status"); const uint64_t code = 200;
        TRY(transit_station_state_put(turn, &status, &code)); owner->result = 2;
    }
    return (transit_sdk_error){0};
}
transit_station_handler http_test_handler(http_test_context *context) { return (transit_station_handler){context, NULL, handle, NULL, NULL}; }
