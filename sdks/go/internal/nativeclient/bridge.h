#pragma once
#include <stddef.h>
#include <stdint.h>

typedef struct transit_go_worker transit_go_worker;
typedef struct transit_go_result {
    uint32_t status;
    uint8_t *data;
    size_t size;
    uint8_t *metadata;
    size_t metadata_size;
    uint32_t diagnostic_valid;
} transit_go_result;

enum transit_go_action { TRANSIT_GO_PREPARE, TRANSIT_GO_INSPECT, TRANSIT_GO_CALL, TRANSIT_GO_QUERY };
/* Every Zig call, including creation and destruction, runs on the owned worker.
 * Arguments remain borrowed only until this synchronous call returns. */
uint32_t transit_go_open(const char *path, const uint8_t *url, size_t url_size,
                        uint32_t timeout, transit_go_worker **out);
transit_go_result transit_go_call(transit_go_worker *, uint32_t action, uint32_t kind,
                                 const uint8_t *seed, const uint8_t *data, size_t size);
void transit_go_result_release(transit_go_result *);
void transit_go_close(transit_go_worker *);
size_t transit_go_stack_size(transit_go_worker *);
