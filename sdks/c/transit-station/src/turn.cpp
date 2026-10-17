#include "internal.hpp"
using namespace transit::sdk::station_detail;
using namespace transit::sdk::internal;
namespace transit::sdk::station_detail {
TurnGuard::TurnGuard(transit_station_turn *turn) {
    require(turn, "turn");
    if (!turn->active.load(std::memory_order_acquire)) fail(TRANSIT_SDK_TURN_EXPIRED, "turn");
    if (turn->thread != std::this_thread::get_id()) fail(TRANSIT_SDK_BUSY, "turn-thread");
    lock = std::unique_lock<std::mutex>(turn->operation, std::try_to_lock);
    if (!lock.owns_lock()) fail(TRANSIT_SDK_BUSY, "turn-reentry");
    if (*turn->stop) fail(TRANSIT_SDK_CLOSED, "local-stop");
    if (turn->poison.kind != TRANSIT_SDK_OK) throw Failure{turn->poison};
}
Bytes turn_apply(transit_station_turn &turn, const std::string &action) { require(turn.bridge, "turn-transport"); return turn.bridge->apply(turn.scope, action); }
void peer(const transit_station_turn &turn, transit_sdk_process value) {
    process(value); require(value.realm == turn.info.process.realm, "peer-realm");
}
std::string application_key(const transit_station_key *key, size_t bound) {
    require(key, "key"); const auto bytes = copy(key->name, bound); require(!bytes.empty() && bytes.front() != 0, "application-key"); return hex(bytes);
}
}
extern "C" {
void transit_station_turn_retain(transit_station_turn *turn) { if (turn) turn->references.fetch_add(1, std::memory_order_relaxed); }
void transit_station_turn_release(transit_station_turn *turn) { if (turn && turn->references.fetch_sub(1, std::memory_order_acq_rel) == 1) delete turn; }
transit_sdk_error transit_station_turn_inspect(transit_station_turn *turn, transit_station_turn_info *out) {
    return with_turn(turn, false, [&](auto &owner) { require(out, "turn-info"); *out = owner.info; });
}
transit_sdk_error transit_station_turn_budgets(transit_station_turn *turn, transit_station_budgets *out) {
    return with_turn(turn, false, [&](auto &owner) {
        require(out, "budgets"); const auto value = turn_apply(owner, "{\"budgets\":{}}"); const auto &raw = owner.bridge->local.raw;
        *out = {raw.number(value, "budgets/mutations", true), raw.number(value, "budgets/outputs", true), raw.number(value, "budgets/views", true),
            raw.number(value, "budgets/retained_reads", true), raw.number(value, "budgets/retains", true), raw.number(value, "budgets/releases", true)};
    });
}
transit_sdk_error transit_station_turn_cast(transit_station_turn *turn, transit_sdk_process destination, const void *value, const transit_station_codec *codec) {
    return with_turn(turn, false, [&](auto &owner) { require(codec, "codec"); peer(owner, destination);
        const auto bytes = encode(*codec, value, owner.bridge->local.caps.message);
        turn_apply(owner, "{\"cast\":{\"pid\":" + decimal(destination.pid) + ",\"value\":" + quote(hex(bytes)) + "}}"); });
}
transit_sdk_error transit_station_turn_call(transit_station_turn *turn, transit_sdk_process destination, const void *value, const transit_station_codec *codec, transit_station_wait wait, uint64_t *correlation) {
    return with_turn(turn, false, [&](auto &owner) { require(codec && correlation, "call"); peer(owner, destination);
        if (wait.timed) { counter(wait.deadline_ms); counter(wait.observer); }
        else require(!wait.deadline_ms && !wait.observer, "untimed-wait");
        const auto bytes = encode(*codec, value, owner.bridge->local.caps.message);
        const auto result = turn_apply(owner, "{\"call\":{\"pid\":" + decimal(destination.pid) + ",\"value\":" + quote(hex(bytes)) + ",\"deadline_ms\":" +
            (wait.timed ? decimal(wait.deadline_ms) : "null") + ",\"observer\":" + (wait.timed ? decimal(wait.observer) : "null") + "}}");
        *correlation = wide(owner.bridge->local.raw, result, "correlation"); require(*correlation, "correlation"); });
}
transit_sdk_error transit_station_turn_reply(transit_station_turn *turn, const void *value, const transit_station_codec *codec) {
    return with_turn(turn, false, [&](auto &owner) { require(codec, "codec");
        turn_apply(owner, "{\"reply\":" + quote(hex(encode(*codec, value, owner.bridge->local.caps.message))) + "}"); });
}
transit_sdk_error transit_station_turn_require_reply(transit_station_turn *turn, transit_sdk_process source, uint64_t correlation) {
    return with_turn(turn, false, [&](auto &owner) { peer(owner, source); require(correlation, "correlation");
        if (owner.input.kind != TRANSIT_INPUT_REPLY || owner.input.origin.kind != TRANSIT_ORIGIN_PROCESS || owner.input.origin.process.pid != source.pid || owner.input.correlation != correlation)
            fail(TRANSIT_SDK_HANDLER_ERROR, "reply-provenance"); });
}
transit_sdk_error transit_station_turn_cancel(transit_station_turn *turn, uint64_t correlation, bool *cancelled) {
    return with_turn(turn, false, [&](auto &owner) { require(correlation && cancelled, "cancel");
        const auto value = turn_apply(owner, "{\"cancel\":" + quote(decimal(correlation)) + "}"); *cancelled = owner.bridge->local.raw.boolean(value, "cancelled"); });
}
transit_sdk_error transit_station_encode_cast(const void *value, const transit_station_codec *codec, const char *native_directory, transit_sdk_buffer *out) {
    Uninterruptible guard; if (out) *out = {};
    return boundary([&] { require(codec && out, "encode-cast"); Worker worker;
        worker.run([&] { Local local(native_directory); const auto bytes = encode(*codec, value, local.caps.message);
            station_buffer *buffer = nullptr; const auto status = local.station_frame_encode(1, 0, bytes.data(), bytes.size(), &buffer);
            const auto encoded = local.result(status, buffer, "encode-cast"); *out = owned(unhex(local.raw.field(encoded, "", true), local.caps.message + 13)); });
    });
}
transit_sdk_error transit_station_state_find(transit_station_turn *turn, const transit_station_read_version *source, const transit_station_key *key, transit_station_value **out) {
    if (out) *out = nullptr;
    return with_turn(turn, true, [&](auto &owner) { require(out, "state-find"); const auto &caps = owner.bridge->local.caps;
        const auto name = application_key(key, caps.key);
        const auto value = turn_apply(owner, source ? "{\"version_get\":{\"id\":" + version(*source) + ",\"key\":" + quote(name) + "}}" : "{\"get\":" + quote(name) + "}");
        const auto &raw = owner.bridge->local.raw;
        if (raw.field(value, "value") != "null") *out = decode(key->codec, unhex(raw.field(value, "value", true), caps.value), caps.value).release(); });
}
transit_sdk_error transit_station_state_put(transit_station_turn *turn, const transit_station_key *key, const void *value) {
    return with_turn(turn, false, [&](auto &owner) { const auto &caps = owner.bridge->local.caps; const auto name = application_key(key, caps.key);
        turn_apply(owner, "{\"put\":{\"key\":" + quote(name) + ",\"value\":" + quote(hex(encode(key->codec, value, caps.value))) + "}}"); });
}
transit_sdk_error transit_station_state_delete(transit_station_turn *turn, const transit_station_key *key) {
    return with_turn(turn, false, [&](auto &owner) { turn_apply(owner, "{\"delete\":" + quote(application_key(key, owner.bridge->local.caps.key)) + "}"); });
}
transit_sdk_error transit_station_state_page(transit_station_turn *turn, const transit_station_read_version *source, const transit_station_cursor *after, transit_station_page **out) {
    if (out) *out = nullptr;
    return with_turn(turn, true, [&](auto &owner) { require(out, "state-page"); const auto &caps = owner.bridge->local.caps;
        const auto value = turn_apply(owner, source ? "{\"version_page\":{\"id\":" + version(*source) + ",\"cursor\":" + cursor(after) + "}}" : "{\"page\":" + cursor(after) + "}");
        const auto &raw = owner.bridge->local.raw; const auto array = raw.field(value, "page/entries");
        if (array.empty() || array.front() != '[' || exists(raw, value, "page/entries/" + decimal(caps.page))) fail(TRANSIT_SDK_INCOMPATIBLE_NATIVE, "page-bound");
        auto page = std::make_unique<transit_station_page>();
        for (size_t i = 0; i < caps.page; ++i) {
            const auto path = "page/entries/" + decimal(i); if (!exists(raw, value, path)) break;
            if (raw.field(value, path) == "null") continue;
            page->entries.push_back({unhex(raw.field(value, path + "/key", true), caps.key), unhex(raw.field(value, path + "/value", true), caps.value), raw.number(value, path + "/revision", true)});
        }
        page->next = next_cursor(raw, value, "page/next"); *out = page.release(); });
}
const void *transit_station_value_data(const transit_station_value *value) { return value ? value->data : nullptr; }
void transit_station_value_destroy(transit_station_value *value) { delete value; }
transit_sdk_error transit_station_turn_retain_source(transit_station_turn *turn, transit_station_read_version *out) {
    return with_turn(turn, false, [&](auto &owner) { require(out, "retain-source"); const auto value = turn_apply(owner, "{\"retain\":{}}"); *out = read_version(owner.bridge->local.raw, value, "version"); });
}
transit_sdk_error transit_station_turn_release_source(transit_station_turn *turn, transit_station_read_version source) {
    return with_turn(turn, false, [&](auto &owner) { turn_apply(owner, "{\"release\":" + version(source) + "}"); });
}
transit_sdk_error transit_station_cursor_import(transit_sdk_bytes bytes, transit_station_cursor **out) {
    if (out) *out = nullptr; return boundary([&] { require(out, "cursor-import"); const auto value = copy(bytes); *out = new transit_station_cursor{std::string(value.begin(), value.end())}; });
}
transit_sdk_error transit_station_cursor_export(const transit_station_cursor *cursor, transit_sdk_buffer *out) {
    if (out) *out = {}; return boundary([&] { require(cursor && out, "cursor-export"); *out = owned(json(cursor->value)); });
}
void transit_station_cursor_destroy(transit_station_cursor *cursor) { delete cursor; }
size_t transit_station_page_size(const transit_station_page *page) { return !page ? 0 : page->entries.size(); }
transit_sdk_error transit_station_page_next(const transit_station_page *page, transit_station_cursor **out) {
    if (out) *out = nullptr; return boundary([&] { require(page && out, "page-next"); if (page->next) *out = new transit_station_cursor{*page->next}; });
}
transit_sdk_error transit_station_page_kv(const transit_station_page *page, size_t index, transit_station_kv_entry *out) {
    return boundary([&] { require(page && out && index < page->entries.size(), "page-entry");
        const auto &entry = page->entries[index]; *out = {view(entry.key), view(entry.value), entry.revision}; });
}
void transit_station_page_destroy(transit_station_page *page) { delete page; }
}
