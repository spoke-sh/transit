#include <transit_station.hpp>
#include "../c/support.h"
#include <iostream>

static std::string field(std::string_view json, std::string_view path, bool raw = true) {
    return std::string(transit::field(json, path, raw).view());
}
int main(int argc, char** argv) {
    require(argc == 4);
    char* source = read_text(argv[1]);
    std::string config(source);
    free(source);
    std::array<std::uint8_t, 32> seed;
    seed_from(field(config, "/seed_file").c_str(), seed.data());
    try {
        transit::GenServer server(field(config, "/url"), seed, field(config, "/server", false));
        erase(seed.data(), seed.size());
        std::string peer(argv[3]);
        require(peer.find_first_not_of("0123456789") == std::string::npos && !peer.empty());
        for (;;) {
            auto owned = server.next(deadline());
            auto event = owned.view();
            auto state = field(event, "/event");
            if (state == "committed") return 0;
            require(state != "idle" && state != "blocked");
            if (state != "ready") continue;
            try {
                if (field(event, "/initializing", false) == "true") {
                    server.apply(R"({"table_create":{"id":1,"key_name":"id","value_name":"value","value_type":"int64"}})");
                    if (std::string_view(argv[2]) == "service") {
                        server.apply("{\"query_policy\":{\"peer\":" + peer + ",\"table\":1,\"expected_revision\":0,\"allow\":true}}");
                        server.apply(R"({"table_write":{"id":1,"mode":"insert","row":{"key":"1","value":{"int64":"9007199254740993"}}}})");
                    }
                }
                auto kind = field(event, "/input/kind");
                if (field(event, "/input/payload") == "696e6974") {}
                else if (kind == "cast") server.apply("{\"call\":{\"pid\":" + peer + ",\"value\":\"7175657279\"}}");
                else if (kind == "call") server.apply(R"({"query_reply":{"id":1}})");
                else if (kind == "result_complete") {
                    auto result = server.apply("{\"query_result\":\"" + field(event, "/input/correlation") + "\"}");
                    auto hex = field(result.view(), "/arrow");
                    std::string ipc(hex.size()/2, '\0');
                    decode(hex.c_str(), reinterpret_cast<std::uint8_t*>(ipc.data()), ipc.size());
                    auto cell = transit::arrow_cell(ipc, 0, 1);
                    require(field(cell.view(), "/value/int64") == "9007199254740993");
                    server.apply(R"({"put":{"key":"6f62736572766564","value":"39303037313939323534373430393933"}})");
                } else throw std::runtime_error("Unexpected Station input");
                server.finish();
            } catch (...) {
                server.finish(true);
                auto failure = server.next(deadline());
                require(field(failure.view(), "/event") == "blocked");
                throw;
            }
        }
    } catch (const std::exception& error) {
        erase(seed.data(), seed.size());
        std::cerr << error.what() << '\n';
        return 1;
    }
}
