#ifndef TRANSIT_TEST_DOCUMENT_H
#define TRANSIT_TEST_DOCUMENT_H
#include <transit/station.h>
#ifdef __cplusplus
extern "C" {
#endif
typedef struct document_test_context {
    const transit_station_document_prepared *changes[2];
    transit_station_turn *escaped;
    int phase;
} document_test_context;
transit_sdk_error document_test_bootstrap(transit_station_document_prepared **out);
transit_station_codec document_test_codec(void);
transit_station_handler document_test_handler(document_test_context *);
#ifdef __cplusplus
}
#endif
#endif
