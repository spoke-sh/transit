#include <transit/sdk_examples.h>
#include <string.h>
static transit_sdk_error invalid(void) { transit_sdk_error value = {0}; value.kind = TRANSIT_SDK_CODEC_ERROR; return value; }
static void u64_put(uint8_t *out, uint64_t value) { for (size_t i = 0; i < 8; ++i) out[i] = (uint8_t)(value >> (i * 8)); }
static uint64_t u64_get(const uint8_t *bytes) { uint64_t value = 0; for (size_t i = 0; i < 8; ++i) value |= (uint64_t)bytes[i] << (i * 8); return value; }
static int64_t i64_get(const uint8_t *bytes) { const uint64_t value = u64_get(bytes); return value <= INT64_MAX ? (int64_t)value : -1 - (int64_t)(UINT64_MAX - value); }
static transit_sdk_error u64_encode(void *context, const void *value, uint8_t *out, size_t capacity, size_t *written) {
    (void)context; if (capacity < 12) return invalid(); memcpy(out, "TSU\1", 4); u64_put(out + 4, *(const uint64_t *)value); *written = 12; return (transit_sdk_error){0};
}
static transit_sdk_error u64_decode(void *context, transit_sdk_bytes bytes, void *out) {
    (void)context; if (bytes.size != 12 || memcmp(bytes.data, "TSU\1", 4)) return invalid(); *(uint64_t *)out = u64_get(bytes.data + 4); return (transit_sdk_error){0};
}
static const uint32_t counter_service = (1u << TRANSIT_COUNTER_ADD) | (1u << TRANSIT_COUNTER_READ);
static const uint32_t counter_requester = (1u << TRANSIT_COUNTER_START) | (1u << TRANSIT_COUNTER_TOTAL);
static const uint32_t counter_total = 1u << TRANSIT_COUNTER_TOTAL;
static const uint32_t query_service = (1u << TRANSIT_QUERY_INITIALIZE) | (1u << TRANSIT_QUERY_INSERT) | (1u << TRANSIT_QUERY_ROWS);
static const uint32_t query_requester = 1u << TRANSIT_QUERY_START;
static transit_sdk_error counter_encode(void *context, const void *value, uint8_t *out, size_t capacity, size_t *written) {
    const transit_counter_message *message = value;
    if (message->tag < 1 || message->tag > 4 || !(*(const uint32_t *)context & (1u << message->tag))) return invalid();
    const size_t size = message->tag == TRANSIT_COUNTER_ADD || message->tag == TRANSIT_COUNTER_TOTAL ? 13 : 5;
    if (capacity < size) return invalid(); memcpy(out, "TSC\1", 4); out[4] = (uint8_t)message->tag;
    if (size == 13) u64_put(out + 5, message->value); *written = size; return (transit_sdk_error){0};
}
static transit_sdk_error counter_decode(void *context, transit_sdk_bytes bytes, void *out) {
    if (bytes.size < 5 || memcmp(bytes.data, "TSC\1", 4)) return invalid(); const uint8_t tag = bytes.data[4];
    if (tag < 1 || tag > 4 || !(*(const uint32_t *)context & (1u << tag))) return invalid();
    const size_t size = tag == TRANSIT_COUNTER_ADD || tag == TRANSIT_COUNTER_TOTAL ? 13 : 5; if (bytes.size != size) return invalid();
    *(transit_counter_message *)out = (transit_counter_message){(transit_counter_tag)tag, size == 13 ? u64_get(bytes.data + 5) : 0}; return (transit_sdk_error){0};
}
static transit_sdk_error query_encode(void *context, const void *value, uint8_t *out, size_t capacity, size_t *written) {
    const transit_query_message *message = value;
    if (message->tag < 1 || message->tag > 4 || !(*(const uint32_t *)context & (1u << message->tag))) return invalid();
    const size_t size = message->tag == TRANSIT_QUERY_INSERT ? (message->has_value ? 22 : 14) : 5;
    if (capacity < size) return invalid(); memcpy(out, "TSQ\1", 4); out[4] = (uint8_t)message->tag;
    if (message->tag == TRANSIT_QUERY_INSERT) { u64_put(out + 5, (uint64_t)message->key); out[13] = message->has_value ? 1 : 0; if (message->has_value) u64_put(out + 14, (uint64_t)message->value); }
    *written = size; return (transit_sdk_error){0};
}
static transit_sdk_error query_decode(void *context, transit_sdk_bytes bytes, void *out) {
    if (bytes.size < 5 || memcmp(bytes.data, "TSQ\1", 4)) return invalid(); const uint8_t tag = bytes.data[4];
    if (tag < 1 || tag > 4 || !(*(const uint32_t *)context & (1u << tag))) return invalid();
    transit_query_message value = {(transit_query_tag)tag, 0, false, 0};
    if (tag == TRANSIT_QUERY_INSERT) {
        if (bytes.size < 14 || bytes.data[13] > 1) return invalid(); value.has_value = bytes.data[13] == 1;
        if (bytes.size != (value.has_value ? 22u : 14u)) return invalid(); value.key = i64_get(bytes.data + 5); if (value.has_value) value.value = i64_get(bytes.data + 14);
    } else if (bytes.size != 5) return invalid();
    *(transit_query_message *)out = value; return (transit_sdk_error){0};
}
transit_station_codec transit_example_u64_codec(void) { return (transit_station_codec){"transit.examples.u64", 1, 12, sizeof(uint64_t), NULL, u64_encode, u64_decode, NULL}; }
transit_station_codec transit_example_counter_codec(void) { return (transit_station_codec){"transit.examples.counter", 1, 13, sizeof(transit_counter_message), (void *)&counter_service, counter_encode, counter_decode, NULL}; }
transit_station_codec transit_example_requester_codec(void) { return (transit_station_codec){"transit.examples.counter", 1, 13, sizeof(transit_counter_message), (void *)&counter_requester, counter_encode, counter_decode, NULL}; }
transit_station_codec transit_example_total_codec(void) { return (transit_station_codec){"transit.examples.counter", 1, 13, sizeof(transit_counter_message), (void *)&counter_total, counter_encode, counter_decode, NULL}; }
transit_station_codec transit_example_query_codec(void) { return (transit_station_codec){"transit.examples.query", 1, 22, sizeof(transit_query_message), (void *)&query_service, query_encode, query_decode, NULL}; }
transit_station_codec transit_example_query_start_codec(void) { return (transit_station_codec){"transit.examples.query", 1, 5, sizeof(transit_query_message), (void *)&query_requester, query_encode, query_decode, NULL}; }
