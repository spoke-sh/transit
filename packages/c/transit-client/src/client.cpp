#include <transit/internal/support.hpp>
#include <charconv>
#include <cstdio>
#include <dlfcn.h>

namespace transit::sdk::internal {
Library::Library(const char *directory, const char *name) {
    std::string base;
    if (directory) base = text(directory, 4096);
    else {
        Dl_info location{};
        if (!dladdr(reinterpret_cast<void *>(&transit_sdk_growing_config), &location) || !location.dli_fname)
            fail(TRANSIT_SDK_INCOMPATIBLE_NATIVE, "native-location");
        const auto file = text(location.dli_fname, 4096);
        const auto separator = file.find_last_of('/');
        if (separator == std::string::npos) fail(TRANSIT_SDK_INCOMPATIBLE_NATIVE, "native-location");
        base = file.substr(0, separator);
    }
    require(!base.empty(), "native-directory");
    handle = dlopen((base + "/" + name).c_str(), RTLD_NOW | RTLD_LOCAL);
    if (!handle) fail(TRANSIT_SDK_INCOMPATIBLE_NATIVE, "native-library");
}
Library::~Library() { if (handle) dlclose(handle); }
void *Library::symbol(const char *name) const {
    auto *address = dlsym(handle, name);
    if (!address) fail(TRANSIT_SDK_INCOMPATIBLE_NATIVE, "native-symbols");
    return address;
}
Raw::Raw(const char *directory) : library(directory, "libtransit_client.so") {
#define LOAD(name) name = reinterpret_cast<decltype(name)>(library.symbol(#name));
    TRANSIT_RAW_FUNCTIONS(LOAD)
#undef LOAD
    if (transit_client_abi_definition_matches(reinterpret_cast<const uint8_t *>(TRANSIT_CLIENT_ABI_DEFINITION), sizeof(TRANSIT_CLIENT_ABI_DEFINITION) - 1) != 1 || transit_client_abi_version() != TRANSIT_CLIENT_ABI_VERSION)
        fail(TRANSIT_SDK_INCOMPATIBLE_NATIVE, "native-version");
    if (transit_client_supports_kind(6) != 1 || transit_client_supports_kind(7) != 1)
        fail(TRANSIT_SDK_UNSUPPORTED_CAPABILITY, "native-capabilities");
}
Bytes Raw::take(transit_buffer *buffer) const {
    std::unique_ptr<transit_buffer, decltype(transit_buffer_destroy)> owner(buffer, transit_buffer_destroy);
    if (!buffer) return {};
    auto size = transit_buffer_size(buffer); auto *data = transit_buffer_data(buffer);
    if (size > TRANSIT_CLIENT_MAX_BODY || (!data && size)) fail(TRANSIT_SDK_INCOMPATIBLE_NATIVE, "native-buffer");
    return size ? Bytes(data, data + size) : Bytes{};
}
std::string Raw::field(const Bytes &json, const std::string &path, bool raw) const {
    const auto selector = path.empty() ? path : "/" + path;
    transit_buffer *buffer = nullptr;
    auto status = transit_json_extract(json.data(), json.size(), reinterpret_cast<const uint8_t *>(selector.data()), selector.size(), raw ? 1 : 0, &buffer);
    auto bytes = take(buffer);
    if (status) fail(TRANSIT_SDK_INCOMPATIBLE_NATIVE, "native-json-field");
    return std::string(bytes.begin(), bytes.end());
}
uint64_t Raw::number(const Bytes &json, const std::string &path, bool zero, bool quoted) const {
    auto value = field(json, path, quoted); uint64_t result = 0;
    auto parsed = std::from_chars(value.data(), value.data() + value.size(), result);
    if (parsed.ec != std::errc{} || parsed.ptr != value.data() + value.size() || std::to_string(result) != value ||
        result > TRANSIT_CLIENT_MAX_COUNTER || (!zero && !result)) fail(TRANSIT_SDK_INCOMPATIBLE_NATIVE, "native-counter");
    return result;
}
bool Raw::boolean(const Bytes &json, const std::string &path) const {
    const auto value = field(json, path); if (value == "true") return true; if (value == "false") return false;
    fail(TRANSIT_SDK_INCOMPATIBLE_NATIVE, "native-boolean");
}
transit_sdk_error Raw::native_error(uint32_t status, const Bytes &json, const char *phase) const {
    std::string code;
    for (const auto *name : {"protocol_error", "err"}) {
        try { code = field(json, name, true); } catch (const Failure &) { continue; } catch (const std::bad_alloc &) { break; }
        if (!code.empty()) break;
    }
    transit_sdk_error_kind kind;
    switch (status) {
        case 2: kind = TRANSIT_SDK_OUT_OF_MEMORY; break;
        case 3: case 5: kind = TRANSIT_SDK_REJECTED; break;
        case 4: kind = TRANSIT_SDK_ACCESS_DENIED; break;
        case 6: kind = TRANSIT_SDK_UNKNOWN_OUTCOME; break;
        case 7: case 8: kind = TRANSIT_SDK_READ_FAILED; break;
        case 9: kind = TRANSIT_SDK_BUSY; break;
        case 10: kind = TRANSIT_SDK_INCOMPATIBLE_NATIVE; break;
        case 11: kind = TRANSIT_SDK_STALE_OWNERSHIP; break;
        case 13: kind = TRANSIT_SDK_TURN_EXPIRED; break;
        default: kind = TRANSIT_SDK_INVALID_ARGUMENT;
    }
    if (status != 6 && (code == "ProcessExpired" || code == "ProcessTerminated")) kind = TRANSIT_SDK_PROCESS_RETIRED;
    if (status != 6 && (code == "HistoryReclaimed" || code == "QueryExpired")) kind = TRANSIT_SDK_HISTORY_UNAVAILABLE;
    if (status != 6 && code == "StaleActivation") kind = TRANSIT_SDK_STALE_OWNERSHIP;
    auto result = error(kind, phase); result.has_native_status = true; result.native_status = status;
    if (code.size() <= 256 && code.find('\0') == std::string::npos) std::copy(code.begin(), code.end(), result.code);
    try {
        const auto detail = field(json, "diagnostic");
        if (detail != "null") {
            if (detail.size() <= 32768 && transit_diagnostic_validate(reinterpret_cast<const uint8_t *>(detail.data()), detail.size()) == 1) {
                result.diagnostic.size = detail.size();
                std::copy(detail.begin(), detail.end(), result.diagnostic.json);
            } else result.diagnostic_invalid = true;
        }
    } catch (const Failure &) { /* No optional detail; retain the primary error. */ }
    catch (const std::bad_alloc &) { result.diagnostic_invalid = true; }
    return result;
}
void Raw::check(uint32_t status, const Bytes &json, const char *phase) const {
    if (status) throw Failure{native_error(status, json, phase)};
}
Bytes Raw::metadata(const Bytes &bytes) const {
    transit_operation *operation = nullptr;
    const auto status = transit_operation_import(bytes.data(), bytes.size(), &operation);
    std::unique_ptr<transit_operation, decltype(transit_operation_destroy)> owner(operation, transit_operation_destroy);
    check(status, {}, "import-operation");
    transit_buffer *buffer = nullptr; const auto result = transit_operation_metadata(operation, &buffer);
    auto json = take(buffer); check(result, json, "operation-metadata"); return json;
}
transit_sdk_mutation_info Raw::info(const Bytes &json) const {
    if (field(json, "version") != "1" || field(json, "profile", true) != "native_v1" || field(json, "kind", true) != "growing_command")
        fail(TRANSIT_SDK_UNSUPPORTED_CAPABILITY, "mutation-metadata");
    transit_sdk_mutation_info out{};
    const auto identity = field(json, "identity", true), command = field(json, "command", true);
    if (identity.size() != 64 || identity.find_first_not_of("0123456789abcdef") != std::string::npos ||
        command.empty() || command.size() > 64 || command.find('\0') != std::string::npos) fail(TRANSIT_SDK_INCOMPATIBLE_NATIVE, "mutation-metadata");
    std::copy(identity.begin(), identity.end(), out.identity); std::copy(command.begin(), command.end(), out.command);
    out.realm = number(json, "realm"); out.principal = number(json, "principal", true); out.sequence = number(json, "sequence", false, true);
    return out;
}
void credential(const transit_sdk_credential &value) {
    counter(value.realm); counter(value.principal, true); require(!text(value.seed_file, 4096).empty(), "credential-path");
}
static void wipe(void *pointer, size_t size) noexcept {
    auto *bytes = static_cast<volatile unsigned char *>(pointer); while (size--) *bytes++ = 0;
}
Seed::Seed(const char *path) {
    struct SecretText { char value[129]{}; ~SecretText() { wipe(value, sizeof(value)); } } input;
    std::unique_ptr<FILE, decltype(&fclose)> file(fopen(path, "rb"), fclose);
    if (!file) fail(TRANSIT_SDK_INVALID_ARGUMENT, "read-credential");
    size_t count = fread(input.value, 1, sizeof(input.value), file.get());
    if (ferror(file.get()) || count == sizeof(input.value)) fail(TRANSIT_SDK_INVALID_ARGUMENT, "read-credential");
    size_t start = 0;
    auto whitespace = [](char c) { return c == ' ' || c == '\r' || c == '\n' || c == '\t'; };
    while (start < count && whitespace(input.value[start])) ++start;
    while (count > start && whitespace(input.value[count - 1])) --count;
    require(count - start == 64, "read-credential");
    auto nibble = [](char c) -> uint8_t {
        if (c >= '0' && c <= '9') return c - '0';
        if (c >= 'a' && c <= 'f') return c - 'a' + 10;
        if (c >= 'A' && c <= 'F') return c - 'A' + 10;
        fail(TRANSIT_SDK_INVALID_ARGUMENT, "read-credential");
    };
    try { for (size_t i = 0; i < 32; ++i) bytes[i] = (nibble(input.value[start + i * 2]) << 4) | nibble(input.value[start + i * 2 + 1]); }
    catch (...) { wipe(bytes.data(), bytes.size()); throw; }
}
Seed::~Seed() { wipe(bytes.data(), bytes.size()); }
std::string hex(const Bytes &bytes) {
    const char *digits = "0123456789abcdef"; std::string out; out.reserve(bytes.size() * 2);
    for (auto byte : bytes) { out += digits[byte >> 4]; out += digits[byte & 15]; } return out;
}
Bytes unhex(const std::string &value, size_t bound) {
    require(value.size() <= bound * 2 && value.size() % 2 == 0, "hex-bound"); Bytes out; out.reserve(value.size() / 2);
    auto nibble = [](char c) -> uint8_t {
        if (c >= '0' && c <= '9') return c - '0'; if (c >= 'a' && c <= 'f') return c - 'a' + 10;
        if (c >= 'A' && c <= 'F') return c - 'A' + 10; fail(TRANSIT_SDK_INCOMPATIBLE_NATIVE, "native-hex");
    };
    for (size_t i = 0; i < value.size(); i += 2) out.push_back((nibble(value[i]) << 4) | nibble(value[i + 1])); return out;
}
std::string quote(const std::string &value) {
    std::string out = "\""; const char *digits = "0123456789abcdef";
    for (unsigned char c : value) {
        if (c == '"' || c == '\\') { out += '\\'; out += c; }
        else if (c < 32) { out += "\\u00"; out += digits[c >> 4]; out += digits[c & 15]; }
        else out += c;
    }
    return out + '"';
}
Bytes Raw::prepare(uint32_t kind, const transit_sdk_credential &identity, const std::string &json) const {
    credential(identity); require(json.size() <= TRANSIT_CLIENT_MAX_BODY, "request-bound"); Seed seed(identity.seed_file);
    transit_operation *operation = nullptr;
    auto status = transit_operation_prepare(kind, seed.data(), reinterpret_cast<const uint8_t *>(json.data()), json.size(), &operation);
    std::unique_ptr<transit_operation, decltype(transit_operation_destroy)> owner(operation, transit_operation_destroy);
    check(status, {}, "prepare-operation");
    transit_buffer *buffer = nullptr; status = transit_operation_export(operation, &buffer);
    auto bytes = take(buffer); check(status, {}, "export-operation"); return bytes;
}
Bytes Raw::call(transit_client *client, const Bytes &bytes, bool mutation) const {
    transit_operation *operation = nullptr;
    const auto imported = transit_operation_import(bytes.data(), bytes.size(), &operation);
    std::unique_ptr<transit_operation, decltype(transit_operation_destroy)> owner(operation, transit_operation_destroy);
    check(imported, {}, "import-operation");
    transit_buffer *buffer = nullptr; const auto status = transit_client_call(client, operation, &buffer);
    Bytes json;
    try { json = take(buffer); } catch (...) { fail(mutation ? TRANSIT_SDK_UNKNOWN_OUTCOME : TRANSIT_SDK_READ_FAILED, "response-buffer"); }
    try { check(status, json, "dispatch"); }
    catch (const Failure &) { throw; }
    catch (...) { fail(mutation ? TRANSIT_SDK_UNKNOWN_OUTCOME : TRANSIT_SDK_READ_FAILED, "response-error"); }
    return json;
}
}
using namespace transit::sdk::internal;
struct transit_sdk_pending_send { Bytes bytes; transit_sdk_send_info info; };
struct transit_sdk_pending_mutation { Bytes bytes; transit_sdk_mutation_info info; };
struct ClientState {
    Raw raw; transit_client *client = nullptr;
    ClientState(const std::string &url, uint32_t timeout, const char *directory) : raw(directory) {
        const auto status = raw.transit_client_create(TRANSIT_CLIENT_ABI_VERSION, reinterpret_cast<const uint8_t *>(url.data()), url.size(), timeout, &client);
        raw.check(status, {}, "open-client");
        if (!client) fail(TRANSIT_SDK_INCOMPATIBLE_NATIVE, "open-client");
    }
    ~ClientState() { raw.transit_client_destroy(client); }
};
struct transit_sdk_client {
    Worker worker; std::unique_ptr<ClientState> state; transit_sdk_shutdown evidence{};
    void close() { worker.close([&] { state.reset(); }); }
    ~transit_sdk_client() { close(); }
};
static std::unique_ptr<transit_sdk_pending_send> send(Raw &raw, Bytes bytes) {
    const auto metadata = raw.metadata(bytes); auto info = raw.info(metadata);
    if (std::strcmp(info.command, "send")) fail(TRANSIT_SDK_UNSUPPORTED_CAPABILITY, "send-metadata");
    const transit_sdk_process peer{info.realm, raw.number(metadata, "destination")};
    return std::make_unique<transit_sdk_pending_send>(transit_sdk_pending_send{std::move(bytes), {info, peer}});
}
extern "C" {
transit_sdk_config transit_sdk_growing_config(const char *url) { return {TRANSIT_SDK_VERSION, url, 30000, nullptr}; }
transit_sdk_error transit_sdk_process_make(uint64_t realm, uint64_t pid, transit_sdk_process *out) {
    return boundary([&] { require(out, "output"); process({realm, pid}); *out = {realm, pid}; });
}
transit_sdk_error transit_sdk_resource_make(uint64_t realm, uint64_t resource, transit_sdk_resource *out) {
    return boundary([&] { require(out, "output"); counter(realm); counter(resource); *out = {realm, resource}; });
}
void transit_sdk_buffer_release(transit_sdk_buffer *buffer) { if (buffer) { delete[] buffer->data; *buffer = {}; } }
transit_sdk_error transit_sdk_client_open(const transit_sdk_config *config, transit_sdk_client **out) {
    Uninterruptible guard;
    if (out) *out = nullptr;
    return boundary([&] {
        require(config && out, "open-client");
        if (config->sdk_version != TRANSIT_SDK_VERSION) fail(TRANSIT_SDK_INCOMPATIBLE_NATIVE, "sdk-version");
        const auto url = text(config->url); require(url.rfind("http://", 0) == 0 || url.rfind("https://", 0) == 0, "url");
        require(config->timeout_ms >= 1 && config->timeout_ms <= 60000, "timeout");
        const auto directory = config->native_directory ? text(config->native_directory, 4096) : std::string{};
        auto client = std::make_unique<transit_sdk_client>();
        client->worker.run([&] { client->state = std::make_unique<ClientState>(url, config->timeout_ms, config->native_directory ? directory.c_str() : nullptr); });
        *out = client.release();
    });
}
transit_sdk_error transit_sdk_client_capabilities(transit_sdk_client *client, const transit_sdk_credential *identity, transit_sdk_capabilities *out) {
    Uninterruptible guard;
    return boundary([&] {
        require(client && identity && out, "capabilities"); credential(*identity);
        client->worker.run([&] {
            auto &raw = client->state->raw;
            auto prepared = raw.prepare(7, *identity, "{\"realm\":" + std::to_string(identity->realm) + ",\"principal\":" + std::to_string(identity->principal) + ",\"kind\":{\"capabilities\":{}}}");
            auto json = raw.call(client->state->client, prepared, false);
            const std::string base = "body/capabilities/";
            if (raw.field(json, "version") != "1" || raw.field(json, base + "version") != "1" || raw.field(json, base + "profile", true) != "growing_v1")
                fail(TRANSIT_SDK_UNSUPPORTED_CAPABILITY, "authority-capabilities");
            *out = {raw.number(json, "realm"), raw.number(json, "position", true), raw.number(json, "principal_sequence", true),
                raw.number(json, base + "page_entries"), raw.number(json, base + "mutation_budget"), raw.number(json, base + "output_budget"),
                raw.boolean(json, base + "retained_read_versions"), raw.boolean(json, base + "association_lookup"), raw.boolean(json, base + "scoped_retry"), raw.boolean(json, base + "station")};
        });
    });
}
transit_sdk_error transit_sdk_client_prepare_send(transit_sdk_client *client, transit_sdk_process peer, transit_sdk_bytes value,
    const transit_sdk_credential *identity, uint64_t sequence, transit_sdk_pending_send **out) {
    Uninterruptible guard; if (out) *out = nullptr;
    return boundary([&] {
        require(client && identity && out, "prepare-send"); process(peer); counter(sequence); credential(*identity);
        require(peer.realm == identity->realm, "send-realm");
        client->worker.run([&] {
            const auto bytes = copy(value, TRANSIT_CLIENT_VALUE_BYTES);
            auto &raw = client->state->raw;
            auto prepared = raw.prepare(6, *identity, "{\"realm\":" + std::to_string(identity->realm) + ",\"principal\":" + std::to_string(identity->principal) + ",\"sequence\":" + std::to_string(sequence) +
                ",\"command\":{\"send\":{\"pid\":" + std::to_string(peer.pid) + ",\"value\":" + quote(hex(bytes)) + "}}}");
            *out = send(raw, std::move(prepared)).release();
        });
    });
}
transit_sdk_error transit_sdk_client_recover_send(transit_sdk_client *client, transit_sdk_bytes input, transit_sdk_pending_send **out) {
    Uninterruptible guard; if (out) *out = nullptr;
    return boundary([&] { require(client && out, "recover-send");
        client->worker.run([&] { *out = send(client->state->raw, copy(input)).release(); }); });
}
transit_sdk_error transit_sdk_client_recover_mutation(transit_sdk_client *client, transit_sdk_bytes input, transit_sdk_pending_mutation **out) {
    Uninterruptible guard; if (out) *out = nullptr;
    return boundary([&] { require(client && out, "recover-mutation");
        client->worker.run([&] { auto bytes = copy(input); auto &raw = client->state->raw; auto info = raw.info(raw.metadata(bytes));
            *out = new transit_sdk_pending_mutation{std::move(bytes), info}; }); });
}
transit_sdk_error transit_sdk_pending_send_info(const transit_sdk_pending_send *pending, transit_sdk_send_info *out) {
    return boundary([&] { require(pending && out, "send-info"); *out = pending->info; });
}
transit_sdk_error transit_sdk_pending_mutation_info(const transit_sdk_pending_mutation *pending, transit_sdk_mutation_info *out) {
    return boundary([&] { require(pending && out, "mutation-info"); *out = pending->info; });
}
transit_sdk_error transit_sdk_pending_send_export(const transit_sdk_pending_send *pending, transit_sdk_buffer *out) {
    if (out) *out = {}; return boundary([&] { require(pending && out, "send-export"); *out = owned(pending->bytes); });
}
transit_sdk_error transit_sdk_pending_mutation_export(const transit_sdk_pending_mutation *pending, transit_sdk_buffer *out) {
    if (out) *out = {}; return boundary([&] { require(pending && out, "mutation-export"); *out = owned(pending->bytes); });
}
void transit_sdk_pending_send_destroy(transit_sdk_pending_send *pending) { delete pending; }
void transit_sdk_pending_mutation_destroy(transit_sdk_pending_mutation *pending) { delete pending; }
}
static transit_sdk_dispatch dispatch(transit_sdk_client *client, const Bytes *input, bool admission) {
    transit_sdk_dispatch result{}; result.outcome = TRANSIT_SDK_PREFLIGHT_FAILED;
    result.error = boundary([&] {
        require(client && input, "dispatch");
        client->worker.run([&] {
            const auto bytes = *input;
            auto &raw = client->state->raw; const auto info = raw.info(raw.metadata(bytes));
            if (admission && std::strcmp(info.command, "send")) fail(TRANSIT_SDK_UNSUPPORTED_CAPABILITY, "send-metadata");
            if (admission) client->evidence.has_admission = false; else client->evidence.has_confirmation = false;
            const auto json = raw.call(client->state->client, bytes, true);
            try { result.position = raw.number(json, "position"); }
            catch (...) { fail(TRANSIT_SDK_UNKNOWN_OUTCOME, "receipt"); }
            if (admission) { client->evidence.has_admission = true; client->evidence.last_admission = {result.position}; }
            else { client->evidence.has_confirmation = true; client->evidence.last_confirmation = {result.position}; }
            result.outcome = admission ? TRANSIT_SDK_ADMITTED : TRANSIT_SDK_CONFIRMED;
        });
    });
    switch (result.error.kind) {
        case TRANSIT_SDK_REJECTED: case TRANSIT_SDK_ACCESS_DENIED: case TRANSIT_SDK_STALE_OWNERSHIP:
        case TRANSIT_SDK_PROCESS_RETIRED: case TRANSIT_SDK_HISTORY_UNAVAILABLE: result.outcome = TRANSIT_SDK_DISPATCH_REJECTED; break;
        case TRANSIT_SDK_UNKNOWN_OUTCOME: result.outcome = TRANSIT_SDK_UNCERTAIN; break;
        default: break;
    }
    return result;
}
extern "C" {
transit_sdk_dispatch transit_sdk_client_dispatch(transit_sdk_client *client, const transit_sdk_pending_send *pending) {
    Uninterruptible guard; return dispatch(client, pending ? &pending->bytes : nullptr, true);
}
transit_sdk_dispatch transit_sdk_client_dispatch_mutation(transit_sdk_client *client, const transit_sdk_pending_mutation *pending) {
    Uninterruptible guard; return dispatch(client, pending ? &pending->bytes : nullptr, false);
}
transit_sdk_error transit_sdk_client_close(transit_sdk_client *client, transit_sdk_shutdown *out) {
    Uninterruptible guard; return boundary([&] { require(client && out, "close-client"); client->close(); *out = client->evidence; });
}
void transit_sdk_client_destroy(transit_sdk_client *client) { Uninterruptible guard; delete client; }
}
