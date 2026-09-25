#include "support.h"

static char* apply(station_server* server, const char* action) {
    station_buffer* result = NULL;
    uint32_t status = station_server_apply(server, (const uint8_t*)action, strlen(action), &result);
    if (status) { station_buffer_destroy(result); require(0); }
    return copy_buffer(result);
}
static void perform(station_server* server, const char* action) { free(apply(server, action)); }

int main(int argc, char** argv) {
    require(argc == 4);
    char* config = read_text(argv[1]);
    char* url = extract(config, "/url", 1);
    char* key = extract(config, "/seed_file", 1);
    char* options = extract(config, "/server", 0);
    uint8_t seed[32];
    seed_from(key, seed);
    station_server* server = NULL;
    require(station_server_create(STATION_ABI_VERSION, (const uint8_t*)url, strlen(url), seed, (const uint8_t*)options, strlen(options), &server) == 0);
    erase(seed, sizeof seed);
    free(config); free(url); free(key); free(options);
    char* end = NULL;
    unsigned long long peer = strtoull(argv[3], &end, 10);
    require(end != argv[3] && *end == 0 && peer > 0 && peer < 9007199254740992ULL);
    char action[512];
    for (;;) {
        station_buffer* result = NULL;
        require(station_server_next(server, deadline(), &result) == 0);
        char* event = copy_buffer(result);
        char* state = extract(event, "/event", 1);
        int committed = strcmp(state, "committed") == 0;
        int ready = strcmp(state, "ready") == 0;
        require(strcmp(state, "idle") != 0 && strcmp(state, "blocked") != 0);
        free(state);
        if (committed) { free(event); break; }
        if (!ready) { free(event); continue; }
        char* initializing = extract(event, "/initializing", 0);
        if (strcmp(initializing, "true") == 0) {
            perform(server, "{\"table_create\":{\"id\":1,\"key_name\":\"id\",\"value_name\":\"value\",\"value_type\":\"int64\"}}");
            if (strcmp(argv[2], "service") == 0) {
                snprintf(action, sizeof action, "{\"query_policy\":{\"peer\":%llu,\"table\":1,\"expected_revision\":0,\"allow\":true}}", peer);
                perform(server, action);
                perform(server, "{\"table_write\":{\"id\":1,\"mode\":\"insert\",\"row\":{\"key\":\"1\",\"value\":{\"int64\":\"9007199254740993\"}}}}");
            }
        }
        free(initializing);
        char* payload = extract(event, "/input/payload", 1);
        char* kind = extract(event, "/input/kind", 1);
        if (strcmp(payload, "696e6974") == 0) { /* initial input */ }
        else if (strcmp(kind, "cast") == 0) {
            snprintf(action, sizeof action, "{\"call\":{\"pid\":%llu,\"value\":\"7175657279\"}}", peer);
            perform(server, action);
        } else if (strcmp(kind, "call") == 0) {
            perform(server, "{\"query_reply\":{\"id\":1}}");
        } else if (strcmp(kind, "result_complete") == 0) {
            char* correlation = extract(event, "/input/correlation", 1);
            snprintf(action, sizeof action, "{\"query_result\":\"%s\"}", correlation);
            free(correlation);
            char* value = apply(server, action);
            char* hex = extract(value, "/arrow", 1);
            free(value);
            uint8_t ipc[672];
            decode(hex, ipc, sizeof ipc);
            size_t length = strlen(hex) / 2;
            free(hex);
            station_buffer* cell = NULL;
            require(station_arrow_cell(ipc, length, 0, 1, &cell) == 0);
            value = copy_buffer(cell);
            char* integer = extract(value, "/value/int64", 1);
            require(strcmp(integer, "9007199254740993") == 0);
            free(integer); free(value);
            perform(server, "{\"put\":{\"key\":\"6f62736572766564\",\"value\":\"39303037313939323534373430393933\"}}");
        } else require(0);
        free(payload); free(kind); free(event);
        require(station_server_finish(server, 0) == 0);
    }
    station_server_destroy(server);
    return 0;
}
