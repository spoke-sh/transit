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
static const uint32_t query_service = (1u << TRANSIT_QUERY_INITIALIZE) | (1u << TRANSIT_QUERY_INSERT) | (1u << TRANSIT_QUERY_ROWS) | (1u << TRANSIT_QUERY_ADVANCE) | (1u << TRANSIT_QUERY_UPDATE) | (1u << TRANSIT_QUERY_DELETE);
static const uint32_t query_requester = (1u << TRANSIT_QUERY_START) | (1u << TRANSIT_QUERY_NOT_READY);
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
    if (message->tag < 1 || message->tag > 8 || !(*(const uint32_t *)context & (1u << message->tag))) return invalid();
    const size_t size = (message->tag == TRANSIT_QUERY_INSERT || message->tag == TRANSIT_QUERY_UPDATE) ? (message->has_value ? 22 : 14) : (message->tag == TRANSIT_QUERY_DELETE ? 13 : 5);
    if (capacity < size) return invalid(); memcpy(out, "TSQ\1", 4); out[4] = (uint8_t)message->tag;
    if (message->tag == TRANSIT_QUERY_INSERT || message->tag == TRANSIT_QUERY_UPDATE) { u64_put(out + 5, (uint64_t)message->key); out[13] = message->has_value ? 1 : 0; if (message->has_value) u64_put(out + 14, (uint64_t)message->value); }
    if (message->tag == TRANSIT_QUERY_DELETE) u64_put(out + 5, (uint64_t)message->key);
    *written = size; return (transit_sdk_error){0};
}
static transit_sdk_error query_decode(void *context, transit_sdk_bytes bytes, void *out) {
    if (bytes.size < 5 || memcmp(bytes.data, "TSQ\1", 4)) return invalid(); const uint8_t tag = bytes.data[4];
    if (tag < 1 || tag > 8 || !(*(const uint32_t *)context & (1u << tag))) return invalid();
    transit_query_message value = {(transit_query_tag)tag, 0, false, 0};
    if (tag == TRANSIT_QUERY_INSERT || tag == TRANSIT_QUERY_UPDATE) {
        if (bytes.size < 14 || bytes.data[13] > 1) return invalid(); value.has_value = bytes.data[13] == 1;
        if (bytes.size != (value.has_value ? 22u : 14u)) return invalid(); value.key = i64_get(bytes.data + 5); if (value.has_value) value.value = i64_get(bytes.data + 14);
    } else if (tag == TRANSIT_QUERY_DELETE) { if (bytes.size != 13) return invalid(); value.key = i64_get(bytes.data + 5); }
    else if (bytes.size != 5) return invalid();
    *(transit_query_message *)out = value; return (transit_sdk_error){0};
}
transit_station_codec transit_example_u64_codec(void) { return (transit_station_codec){"transit.examples.u64", 1, 12, sizeof(uint64_t), NULL, u64_encode, u64_decode, NULL}; }
transit_station_codec transit_example_counter_codec(void) { return (transit_station_codec){"transit.examples.counter", 1, 13, sizeof(transit_counter_message), (void *)&counter_service, counter_encode, counter_decode, NULL}; }
transit_station_codec transit_example_requester_codec(void) { return (transit_station_codec){"transit.examples.counter", 1, 13, sizeof(transit_counter_message), (void *)&counter_requester, counter_encode, counter_decode, NULL}; }
transit_station_codec transit_example_total_codec(void) { return (transit_station_codec){"transit.examples.counter", 1, 13, sizeof(transit_counter_message), (void *)&counter_total, counter_encode, counter_decode, NULL}; }
transit_station_codec transit_example_query_codec(void) { return (transit_station_codec){"transit.examples.query", 1, 22, sizeof(transit_query_message), (void *)&query_service, query_encode, query_decode, NULL}; }
transit_station_codec transit_example_query_start_codec(void) { return (transit_station_codec){"transit.examples.query", 1, 5, sizeof(transit_query_message), (void *)&query_requester, query_encode, query_decode, NULL}; }

#define MAX_INPUT UINT64_C(9007199254740991)
static bool queue_valid(const transit_example_table_queue *v) {
    return v->tail <= MAX_INPUT && ((v->head == 0) == (v->tail == 0)) &&
        (v->head == UINT64_MAX || v->head <= v->tail) && (v->head != UINT64_MAX || !v->ready);
}
static transit_sdk_error queue_encode(void *context, const void *value, uint8_t *out, size_t capacity, size_t *written) {
    (void)context; const transit_example_table_queue *v = value; if (capacity < 21 || !queue_valid(v)) return invalid();
    memcpy(out, "TQM\1", 4); u64_put(out+4,v->head); u64_put(out+12,v->tail); out[20]=v->ready; *written=21; return (transit_sdk_error){0};
}
static transit_sdk_error queue_decode(void *context, transit_sdk_bytes bytes, void *out) {
    (void)context; if(bytes.size!=21 || memcmp(bytes.data,"TQM\1",4) || bytes.data[20]>1) return invalid();
    transit_example_table_queue v={u64_get(bytes.data+4),u64_get(bytes.data+12),bytes.data[20]!=0};
    if(!queue_valid(&v)) return invalid(); *(transit_example_table_queue *)out=v; return (transit_sdk_error){0};
}
static bool work_valid(const transit_example_table_work *v) {
    return v->next<=MAX_INPUT && (v->command.tag==TRANSIT_QUERY_INITIALIZE || v->command.tag==TRANSIT_QUERY_INSERT || v->command.tag==TRANSIT_QUERY_UPDATE || v->command.tag==TRANSIT_QUERY_DELETE);
}
static transit_sdk_error work_encode(void *context, const void *value, uint8_t *out, size_t capacity, size_t *written) {
    (void)context; const transit_example_table_work *v=value; if(capacity<12 || !work_valid(v)) return invalid();
    size_t count=0; transit_sdk_error error=query_encode((void *)&query_service,&v->command,out+12,capacity-12,&count); if(error.kind) return error;
    memcpy(out,"TQW\1",4); u64_put(out+4,v->next); *written=12+count; return (transit_sdk_error){0};
}
static transit_sdk_error work_decode(void *context, transit_sdk_bytes bytes, void *out) {
    (void)context; if((bytes.size!=17 && bytes.size!=25 && bytes.size!=26 && bytes.size!=34) || memcmp(bytes.data,"TQW\1",4)) return invalid();
    transit_example_table_work v={0}; v.next=u64_get(bytes.data+4);
    transit_sdk_error error=query_decode((void *)&query_service,(transit_sdk_bytes){bytes.data+12,bytes.size-12},&v.command); if(error.kind) return error;
    if(!work_valid(&v)) return invalid(); *(transit_example_table_work *)out=v; return (transit_sdk_error){0};
}
static bool outcome_valid(const transit_example_table_outcome *v) {
    return v->state<=3 && v->admitted>0 && v->completed>=v->admitted && v->completed<=MAX_INPUT && v->changed<=v->matched && v->rejection<=7 &&
        (v->state==1 || (!v->matched && !v->changed)) && ((v->state==2)==(v->rejection!=0));
}
static transit_sdk_error outcome_encode(void *context, const void *value, uint8_t *out, size_t capacity, size_t *written) {
    (void)context; const transit_example_table_outcome *v=value; if(capacity<38 || !outcome_valid(v)) return invalid();
    memcpy(out,"TQO\1",4); out[4]=v->state; u64_put(out+5,v->admitted); u64_put(out+13,v->completed); u64_put(out+21,v->matched); u64_put(out+29,v->changed); out[37]=v->rejection; *written=38; return (transit_sdk_error){0};
}
static transit_sdk_error outcome_decode(void *context, transit_sdk_bytes bytes, void *out) {
    (void)context; if(bytes.size!=38 || memcmp(bytes.data,"TQO\1",4)) return invalid();
    transit_example_table_outcome v={bytes.data[4],u64_get(bytes.data+5),u64_get(bytes.data+13),u64_get(bytes.data+21),u64_get(bytes.data+29),bytes.data[37]};
    if(!outcome_valid(&v)) return invalid(); *(transit_example_table_outcome *)out=v; return (transit_sdk_error){0};
}
transit_station_codec transit_example_table_queue_codec(void) { return (transit_station_codec){"transit.examples.table.queue",1,21,sizeof(transit_example_table_queue),NULL,queue_encode,queue_decode,NULL}; }
transit_station_codec transit_example_table_work_codec(void) { return (transit_station_codec){"transit.examples.table.work",1,34,sizeof(transit_example_table_work),NULL,work_encode,work_decode,NULL}; }
transit_station_codec transit_example_table_outcome_codec(void) { return (transit_station_codec){"transit.examples.table.outcome",1,38,sizeof(transit_example_table_outcome),NULL,outcome_encode,outcome_decode,NULL}; }
