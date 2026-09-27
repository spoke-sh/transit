#ifndef TRANSIT_TEST_GRPC_SDK_H
#define TRANSIT_TEST_GRPC_SDK_H
#include <transit/sdk_examples.h>
#ifdef __cplusplus
extern "C" {
#endif
typedef struct grpc_test_context {
    transit_sdk_process peer;
    const transit_station_grpc_request *request;
    transit_station_turn *escaped;
    unsigned result;
    transit_station_grpc_released disposal;
    transit_station_grpc_outcome parent;
} grpc_test_context;
transit_sdk_error grpc_test_prepare(uint64_t resource, transit_sdk_bytes descriptor, transit_sdk_bytes body, uint64_t deadline, transit_station_grpc_request **out);
transit_station_codec grpc_test_codec(grpc_test_context *context);
transit_station_handler grpc_test_handler(grpc_test_context *context);
#ifdef __cplusplus
}
#endif
#endif
