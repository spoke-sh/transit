#include "transit_client.h"
#include <assert.h>
#include <string.h>

int main(void) {
    assert(transit_client_abi_version() == TRANSIT_CLIENT_ABI_VERSION);
    transit_client *client = NULL;
    const uint8_t url[] = "http://127.0.0.1:1";
    assert(transit_client_create(99, url, sizeof(url) - 1, 100, &client) == TRANSIT_STATUS_INCOMPATIBLE_VERSION);
    assert(client == NULL);
    assert(transit_client_create(1, url, sizeof(url) - 1, 100, &client) == TRANSIT_STATUS_OK);
    const uint8_t seed[32] = {7};
    const uint8_t request[] = "{\"realm\":1,\"principal\":0,\"sequence\":1,\"command\":{\"spawn\":{}}}";
    transit_operation *operation = NULL;
    assert(transit_operation_prepare(99, seed, request, sizeof(request) - 1, &operation) == TRANSIT_STATUS_INVALID_ARGUMENT);
    assert(operation == NULL);
    assert(transit_operation_prepare(TRANSIT_KIND_GROWING_COMMAND, seed, request, sizeof(request) - 1, &operation) == TRANSIT_STATUS_OK);
    transit_buffer *saved = NULL;
    assert(transit_operation_export(operation, &saved) == TRANSIT_STATUS_OK);
    transit_operation_destroy(operation);
    operation = NULL;
    assert(transit_operation_import(transit_buffer_data(saved), transit_buffer_size(saved), &operation) == TRANSIT_STATUS_OK);
    transit_buffer *again = NULL;
    assert(transit_operation_export(operation, &again) == TRANSIT_STATUS_OK);
    assert(transit_buffer_size(saved) == transit_buffer_size(again));
    assert(memcmp(transit_buffer_data(saved), transit_buffer_data(again), transit_buffer_size(saved)) == 0);
    transit_buffer_destroy(again);
    transit_buffer_destroy(saved);
    transit_operation_destroy(operation);
    transit_client_destroy(client);
    transit_client_destroy(NULL);
    transit_operation_destroy(NULL);
    transit_buffer_destroy(NULL);
    return 0;
}
