#ifndef TRANSIT_TEST_HTTP_SDK_H
#define TRANSIT_TEST_HTTP_SDK_H
#include <transit/sdk_examples.h>
#ifdef __cplusplus
extern "C" {
#endif
typedef struct http_test_context {
    transit_sdk_process peer;
    const transit_station_http_request *request;
    transit_station_turn *escaped;
    unsigned result;
    transit_station_http_released disposal;
    transit_station_http_outcome parent;
    transit_station_http_followup_reason followup_reason;
} http_test_context;
transit_sdk_error http_test_prepare(uint64_t resource, transit_sdk_bytes body, uint64_t deadline, bool rich, transit_station_http_request **out);
transit_station_codec http_test_codec(http_test_context *context);
transit_station_handler http_test_handler(http_test_context *context);
#ifdef __cplusplus
}
#endif
#endif
