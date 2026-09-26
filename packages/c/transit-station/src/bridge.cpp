#include "internal.hpp"
#include <charconv>
#include <chrono>

namespace transit::sdk::station_detail {
Local::Local(const char *directory) : raw(directory), library(directory, "libtransit_station.so") {
#define LOAD(name) name = reinterpret_cast<decltype(name)>(library.symbol(#name));
    TRANSIT_STATION_FUNCTIONS(LOAD)
#undef LOAD
    if (station_abi_version() != STATION_ABI_VERSION) fail(TRANSIT_SDK_INCOMPATIBLE_NATIVE, "station-version");
    station_buffer *buffer = nullptr; const auto status = station_growing_capabilities(&buffer);
    const auto value = result(status, buffer, "native-capabilities");
    if (raw.field(value, "version") != "1" || raw.field(value, "profile", true) != "growing_v3") fail(TRANSIT_SDK_UNSUPPORTED_CAPABILITY, "station-profile");
    for (const auto *flag : {"gated_dispatch", "retained_confirmation", "scoped_turns", "paged_state", "tables", "retained_sources"})
        if (!raw.boolean(value, flag)) fail(TRANSIT_SDK_UNSUPPORTED_CAPABILITY, "station-capabilities");
    caps = {raw.number(value, "message_bytes"), raw.number(value, "value_bytes"), raw.number(value, "key_bytes"),
        raw.number(value, "table_cell_bytes"), raw.number(value, "table_name_bytes"), raw.number(value, "page_entries"),
        raw.number(value, "query_segment_bytes"), raw.boolean(value, "query_results")};
    for (auto bound : {caps.message, caps.value, caps.key, caps.cell, caps.name, caps.page, caps.segment})
        if (bound > TRANSIT_CLIENT_MAX_BODY) fail(TRANSIT_SDK_INCOMPATIBLE_NATIVE, "native-bound");
}
Bytes Local::take(station_buffer *buffer) const {
    std::unique_ptr<station_buffer, decltype(station_buffer_destroy)> owner(buffer, station_buffer_destroy);
    if (!buffer) return {};
    const auto size = station_buffer_size(buffer); const auto *data = station_buffer_data(buffer);
    if (size > TRANSIT_CLIENT_MAX_BODY || (!data && size)) fail(TRANSIT_SDK_INCOMPATIBLE_NATIVE, "station-buffer");
    return size ? Bytes(data, data + size) : Bytes{};
}
Bytes Local::result(uint32_t status, station_buffer *buffer, const char *phase, bool mutation) const {
    Bytes value;
    try { value = take(buffer); }
    catch (...) { fail(mutation ? TRANSIT_SDK_UNKNOWN_OUTCOME : TRANSIT_SDK_READ_FAILED, phase); }
    try { raw.check(status, value, phase); }
    catch (const Failure &) { throw; }
    catch (...) { fail(mutation ? TRANSIT_SDK_UNKNOWN_OUTCOME : TRANSIT_SDK_READ_FAILED, phase); }
    return value;
}
Bridge::Bridge(const transit_station_config &config, transit_station_failure_policy failure)
    : local(config.client.native_directory), client(nullptr, local.raw.transit_client_destroy), server(nullptr, local.station_growing_destroy) {
    if (config.client.sdk_version != TRANSIT_SDK_VERSION) fail(TRANSIT_SDK_INCOMPATIBLE_NATIVE, "sdk-version");
    process(config.process); credential(config.credential); counter(config.generation);
    require(config.credential.realm == config.process.realm, "activation-realm");
    const auto association = text(config.association, local.caps.key); require(!association.empty(), "association");
    if (config.query_results && !local.caps.queries) fail(TRANSIT_SDK_UNSUPPORTED_CAPABILITY, "query-results");
    const auto url = text(config.client.url);
    transit_client *raw_client = nullptr;
    const auto created = local.raw.transit_client_create(TRANSIT_CLIENT_ABI_VERSION, reinterpret_cast<const uint8_t *>(url.data()), url.size(), config.client.timeout_ms, &raw_client);
    client.reset(raw_client); local.raw.check(created, {}, "open-client");
    const auto realm = decimal(config.process.realm), principal = decimal(config.credential.principal);
    const auto prepared = local.raw.prepare(7, config.credential, "{\"realm\":" + realm + ",\"principal\":" + principal + ",\"kind\":{\"capabilities\":{}}}");
    const auto authority = local.raw.call(client.get(), prepared, false);
    if (local.raw.field(authority, "version") != "3" || local.raw.field(authority, "body/capabilities/version") != "3" || local.raw.field(authority, "body/capabilities/profile", true) != "growing_v1")
        fail(TRANSIT_SDK_UNSUPPORTED_CAPABILITY, "authority-profile");
    for (const auto *flag : {"association_lookup", "scoped_retry", "retained_read_versions"})
        if (!local.raw.boolean(authority, std::string("body/capabilities/") + flag)) fail(TRANSIT_SDK_UNSUPPORTED_CAPABILITY, "authority-capabilities");
    const auto settings = "{\"profile\":\"growing_v3\",\"realm\":" + realm + ",\"principal\":" + principal + ",\"pid\":" + decimal(config.process.pid) +
        ",\"generation\":" + decimal(config.generation) + ",\"association\":" + quote(association) + ",\"timeout_ms\":" + decimal(config.client.timeout_ms) +
        ",\"failure_policy\":" + quote(failure == TRANSIT_FAILURE_STOP ? "stop" : "block_input") + ",\"query_results\":" + (config.query_results ? "true" : "false") + "}";
    Seed seed(config.credential.seed_file); station_growing_server *handle = nullptr;
    const auto opened = local.station_growing_create(STATION_ABI_VERSION, reinterpret_cast<const uint8_t *>(url.data()), url.size(), seed.data(), reinterpret_cast<const uint8_t *>(settings.data()), settings.size(), &handle);
    server.reset(handle); local.raw.check(opened, {}, "open-runner");
    if (!handle) fail(TRANSIT_SDK_INCOMPATIBLE_NATIVE, "open-runner");
}
Bytes Bridge::prepare() {
    const auto now = std::chrono::duration_cast<std::chrono::milliseconds>(std::chrono::system_clock::now().time_since_epoch()).count();
    if (now < 0 || static_cast<uint64_t>(now) > TRANSIT_CLIENT_MAX_COUNTER - 30000) fail(TRANSIT_SDK_READ_FAILED, "clock");
    station_buffer *buffer = nullptr; const auto status = local.station_growing_prepare(server.get(), now + 30000, &buffer);
    return local.result(status, buffer, "prepare-turn");
}
Bytes Bridge::apply(uint64_t scope, const std::string &action) {
    require(action.size() <= TRANSIT_CLIENT_MAX_BODY, "action-bound");
    station_buffer *buffer = nullptr;
    const auto status = local.station_growing_apply(server.get(), scope, reinterpret_cast<const uint8_t *>(action.data()), action.size(), &buffer);
    return local.result(status, buffer, "apply");
}
void Bridge::finish(uint64_t scope, bool failed) {
    station_buffer *buffer = nullptr; const auto status = local.station_growing_finish_result(server.get(), scope, failed ? 1 : 0, &buffer);
    local.result(status, buffer, "finish");
}
void Bridge::discard(uint64_t scope) { local.raw.check(local.station_growing_discard(server.get(), scope), {}, "discard"); }
std::shared_ptr<const transit_station_mutation> Bridge::pending(const Bytes &event) {
    auto mutation = std::make_shared<transit_station_mutation>();
    const auto purpose = local.raw.field(event, "pending_kind", true);
    if (purpose == "permit") mutation->info.purpose = TRANSIT_MUTATION_PERMIT;
    else if (purpose == "open") mutation->info.purpose = TRANSIT_MUTATION_OPEN;
    else if (purpose == "commit") mutation->info.purpose = TRANSIT_MUTATION_COMMIT;
    else fail(TRANSIT_SDK_INCOMPATIBLE_NATIVE, "pending-purpose");
    mutation->info.input = local.raw.number(event, "pending_input");
    station_buffer *buffer = nullptr; const auto status = local.station_growing_pending(server.get(), &buffer);
    mutation->bytes = local.result(status, buffer, "pending");
    mutation->info.operation = local.raw.info(local.raw.metadata(mutation->bytes));
    const std::string command(mutation->info.operation.command);
    if (!(purpose == "permit" ? command == "begin_turn" : purpose == "open" ? command == "open_view" : (command == "turn" || command == "turn_with_versions")))
        fail(TRANSIT_SDK_INCOMPATIBLE_NATIVE, "pending-command");
    return mutation;
}
Bytes Bridge::dispatch() {
    station_buffer *buffer = nullptr; const auto status = local.station_growing_dispatch(server.get(), &buffer);
    return local.result(status, buffer, "dispatch", true);
}
std::optional<Bytes> Bridge::confirmation(const transit_station_mutation &pending) {
    station_buffer *buffer = nullptr; const auto status = local.station_growing_confirmation(server.get(), &buffer);
    Bytes value;
    try { value = local.result(status, buffer, "observe-confirmation"); }
    catch (const Failure &error) { if (error.value.kind == TRANSIT_SDK_TURN_EXPIRED) return {}; throw; }
    const auto kind = local.raw.field(value, "confirmation/kind", true);
    const char *expected = pending.info.purpose == TRANSIT_MUTATION_PERMIT ? "permit" : pending.info.purpose == TRANSIT_MUTATION_OPEN ? "open" : "commit";
    if (kind != expected || local.raw.number(value, "confirmation/input") != pending.info.input) return {};
    return value;
}
bool exists(const Raw &raw, const Bytes &value, const std::string &path) {
    try { raw.field(value, path); return true; }
    catch (const Failure &error) { if (error.value.kind == TRANSIT_SDK_INCOMPATIBLE_NATIVE) return false; throw; }
}
uint64_t wide(const Raw &raw, const Bytes &value, const std::string &path) {
    const auto text = raw.field(value, path, true); uint64_t result;
    const auto parsed = std::from_chars(text.data(), text.data() + text.size(), result);
    if (parsed.ec != std::errc{} || parsed.ptr != text.data() + text.size() || decimal(result) != text) fail(TRANSIT_SDK_INCOMPATIBLE_NATIVE, "native-u64");
    return result;
}
int64_t signed_number(const Raw &raw, const Bytes &value, const std::string &path) {
    const auto text = raw.field(value, path, true); int64_t result;
    const auto parsed = std::from_chars(text.data(), text.data() + text.size(), result);
    if (parsed.ec != std::errc{} || parsed.ptr != text.data() + text.size() || signed_decimal(result) != text) fail(TRANSIT_SDK_INCOMPATIBLE_NATIVE, "native-i64");
    return result;
}
void digest(const Raw &raw, const Bytes &value, const std::string &path, uint8_t out[32]) {
    const auto array = raw.field(value, path);
    if (array.empty() || array.front() != '[' || exists(raw, value, path + "/32")) fail(TRANSIT_SDK_INCOMPATIBLE_NATIVE, "digest");
    for (size_t i = 0; i < 32; ++i) {
        const auto byte = raw.number(value, path + "/" + decimal(i), true);
        if (byte > 255) fail(TRANSIT_SDK_INCOMPATIBLE_NATIVE, "digest"); out[i] = static_cast<uint8_t>(byte);
    }
}
std::string version(const transit_station_read_version &value) {
    counter(value.pid); counter(value.input);
    return "{\"pid\":" + decimal(value.pid) + ",\"input\":" + decimal(value.input) + ",\"index\":" + decimal(value.index) + "}";
}
transit_station_read_version read_version(const Raw &raw, const Bytes &value, const std::string &path) {
    const auto index = raw.number(value, path + "/index", true);
    if (index > 255) fail(TRANSIT_SDK_INCOMPATIBLE_NATIVE, "read-version");
    return {raw.number(value, path + "/pid"), raw.number(value, path + "/input"), static_cast<uint8_t>(index)};
}
transit_station_basis basis(const Raw &raw, const Bytes &value, const std::string &path, uint64_t realm) {
    transit_station_basis result{}; result.resource = {realm, raw.number(value, path + "/resource")};
    result.revision = raw.number(value, path + "/revision", true); digest(raw, value, path + "/schema", result.schema); return result;
}
std::string cursor(const transit_station_cursor *value) { return value ? quote(value->value) : "null"; }
std::optional<std::string> next_cursor(const Raw &raw, const Bytes &value, const std::string &path) {
    if (raw.field(value, path) == "null") return {}; return raw.field(value, path, true);
}
void callback_result(transit_sdk_error error) { if (error.kind != TRANSIT_SDK_OK) throw Failure{error}; }
void codec_contract(const transit_station_codec &codec, size_t bound) {
    if (!codec.type_id || strnlen(codec.type_id, TRANSIT_CLIENT_MAX_BODY + 1) == 0 || strnlen(codec.type_id, TRANSIT_CLIENT_MAX_BODY + 1) > TRANSIT_CLIENT_MAX_BODY ||
        !codec.version || !codec.object_bytes || codec.object_bytes > TRANSIT_CLIENT_MAX_BODY || !codec.max_encoded_bytes || codec.max_encoded_bytes > bound || !codec.encode || !codec.decode)
        fail(TRANSIT_SDK_CODEC_ERROR, "codec-contract");
}
Bytes encode(const transit_station_codec &codec, const void *value, size_t bound) {
    codec_contract(codec, bound); require(value, "codec-value"); Bytes bytes(codec.max_encoded_bytes); size_t written = 0;
    const auto error = boundary([&] { callback_result(codec.encode(codec.context, value, bytes.data(), bytes.size(), &written)); });
    if (error.kind != TRANSIT_SDK_OK || written > bytes.size()) fail(TRANSIT_SDK_CODEC_ERROR, "encode");
    bytes.resize(written); return bytes;
}
std::unique_ptr<transit_station_value> decode(const transit_station_codec &codec, const Bytes &bytes, size_t bound) {
    codec_contract(codec, bound); if (bytes.size() > codec.max_encoded_bytes) fail(TRANSIT_SDK_CODEC_ERROR, "decode-bound");
    auto value = std::make_unique<transit_station_value>(codec);
    const auto error = boundary([&] { callback_result(codec.decode(codec.context, view(bytes), value->data)); });
    if (error.kind != TRANSIT_SDK_OK) fail(TRANSIT_SDK_CODEC_ERROR, "decode");
    value->constructed = true; return value;
}
transit_station_origin origin(const Raw &raw, const Bytes &event, uint64_t realm) {
    transit_station_origin out{}; const std::string path = "input/origin/";
    if (exists(raw, event, path + "external")) {
        out.kind = TRANSIT_ORIGIN_EXTERNAL; out.principal = raw.number(event, path + "external/principal", true); out.policy_revision = raw.number(event, path + "external/policy_revision");
    } else if (exists(raw, event, path + "process")) {
        out.kind = TRANSIT_ORIGIN_PROCESS; out.process = {realm, raw.number(event, path + "process/pid")}; out.turn = raw.number(event, path + "process/turn"); out.output = raw.number(event, path + "process/output", true);
    } else if (exists(raw, event, path + "effect")) {
        out.kind = TRANSIT_ORIGIN_EFFECT; out.effect = raw.number(event, path + "effect/id"); out.attempt = raw.number(event, path + "effect/attempt"); out.executor = raw.number(event, path + "effect/executor", true);
    } else fail(TRANSIT_SDK_INCOMPATIBLE_NATIVE, "input-origin");
    return out;
}
transit_station_incoming incoming(const Raw &raw, const Bytes &event, uint64_t realm) {
    transit_station_incoming out{}; const auto kind = raw.field(event, "input/kind", true);
    if (kind == "cast") out.kind = TRANSIT_INPUT_CAST;
    else if (kind == "call") out.kind = TRANSIT_INPUT_CALL;
    else if (kind == "reply") out.kind = TRANSIT_INPUT_REPLY;
    else if (kind == "cancel") out.kind = TRANSIT_INPUT_CANCEL;
    else if (kind == "timeout") out.kind = TRANSIT_INPUT_TIMEOUT;
    else if (kind == "result_complete") out.kind = TRANSIT_INPUT_RESULT_COMPLETE;
    else fail(TRANSIT_SDK_HANDLER_ERROR, "unsupported-native-input");
    out.position = raw.number(event, "input/position"); out.origin = origin(raw, event, realm);
    if (out.kind != TRANSIT_INPUT_CAST) { out.correlation = wide(raw, event, "input/correlation"); require(out.correlation, "input-correlation"); }
    return out;
}
}
