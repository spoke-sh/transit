#ifndef TRANSIT_C_SDK_EXAMPLES_H
#define TRANSIT_C_SDK_EXAMPLES_H
#include <transit/station.h>
#include <transit/table.h>
#ifdef __cplusplus
extern "C" {
#endif
typedef enum transit_counter_tag { TRANSIT_COUNTER_ADD = 1, TRANSIT_COUNTER_READ = 2, TRANSIT_COUNTER_START = 3, TRANSIT_COUNTER_TOTAL = 4 } transit_counter_tag;
typedef struct transit_counter_message { transit_counter_tag tag; uint64_t value; } transit_counter_message;
typedef enum transit_query_tag { TRANSIT_QUERY_INITIALIZE = 1, TRANSIT_QUERY_INSERT = 2, TRANSIT_QUERY_ROWS = 3, TRANSIT_QUERY_START = 4,
    TRANSIT_QUERY_ADVANCE = 5, TRANSIT_QUERY_NOT_READY = 6, TRANSIT_QUERY_UPDATE = 7, TRANSIT_QUERY_DELETE = 8 } transit_query_tag;
typedef struct transit_query_message { transit_query_tag tag; int64_t key; bool has_value; int64_t value; } transit_query_message;
typedef struct transit_example_peer { transit_sdk_process peer; } transit_example_peer;
typedef struct transit_example_query_requester {
    transit_sdk_process source;
    void *context;
    transit_sdk_error (*consume)(void *context, const transit_station_segment *segment);
} transit_example_query_requester;
transit_station_codec transit_example_counter_codec(void);
transit_station_codec transit_example_requester_codec(void);
transit_station_codec transit_example_total_codec(void);
transit_station_codec transit_example_u64_codec(void);
transit_station_codec transit_example_query_codec(void);
transit_station_codec transit_example_query_start_codec(void);
transit_station_key transit_example_total_key(void);
transit_station_key transit_example_request_key(void);
transit_station_key transit_example_observed_key(void);
transit_station_key transit_example_not_ready_key(void);
transit_station_catalog_schema transit_example_table(void);
transit_station_catalog_limits transit_example_table_limits(void);
transit_logical_cell_view transit_example_signed(int64_t value);
typedef struct transit_example_table_queue { uint64_t head, tail; bool ready; } transit_example_table_queue;
typedef struct transit_example_table_work { uint64_t next; transit_query_message command; } transit_example_table_work;
typedef struct transit_example_table_outcome { uint8_t state; uint64_t admitted, completed, matched, changed; uint8_t rejection; } transit_example_table_outcome;
transit_station_codec transit_example_table_queue_codec(void);
transit_station_codec transit_example_table_work_codec(void);
transit_station_codec transit_example_table_outcome_codec(void);
transit_station_handler transit_example_counter_handler(void);
transit_station_handler transit_example_requester_handler(transit_example_peer *context);
transit_station_handler transit_example_table_handler(transit_example_peer *context);
transit_station_handler transit_example_query_requester_handler(transit_example_query_requester *context);
#ifdef __cplusplus
}
#endif
#endif
