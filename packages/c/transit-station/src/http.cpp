#include "internal.hpp"
using namespace transit::sdk::internal;
using namespace transit::sdk::station_detail;

namespace {
std::string piece_text(transit_sdk_bytes value, size_t bound) {
    const auto bytes = copy(value, bound); return std::string(bytes.begin(), bytes.end());
}
std::string pieces(const transit_station_http_piece *values, size_t count) {
    require(count <= 128 && (values || !count), "http-pieces");
    std::string out = "[";
    for (size_t i = 0; i < count; ++i) {
        if (i) out += ',';
        const auto &piece = values[i];
        if (piece.kind == TRANSIT_HTTP_LITERAL) out += "{\"literal\":" + quote(piece_text(piece.value, 8192)) + "}";
        else if (piece.kind == TRANSIT_HTTP_VARIABLE) out += "{\"variable\":{\"name\":" + quote(piece_text(piece.name, 128)) + ",\"value\":" + quote(piece_text(piece.value, 8192)) + "}}";
        else if (piece.kind == TRANSIT_HTTP_SECRET) {
            require(piece.version != 0, "http-secret-version");
            out += "{\"secret\":{\"binding\":" + quote(piece_text(piece.name, 128)) + ",\"version\":" + quote(decimal(piece.version)) + "}}";
        } else fail(TRANSIT_SDK_INVALID_ARGUMENT, "http-piece");
        require(out.size() <= TRANSIT_CLIENT_MAX_BODY, "http-piece-bound");
    }
    return out + ']';
}
Bytes codec(Local &local, const std::string &action) {
    require(action.size() <= TRANSIT_CLIENT_MAX_BODY, "http-codec-bound");
    if (!local.caps.http_requests) fail(TRANSIT_SDK_UNSUPPORTED_CAPABILITY, "http-requests");
    station_buffer *buffer = nullptr;
    const auto status = local.station_http_codec(reinterpret_cast<const uint8_t *>(action.data()), action.size(), &buffer);
    return local.result(status, buffer, "http-codec");
}
void request_scope(const transit_station_turn &turn, const transit_station_http_request *request) {
    require(request && request->resource.realm == turn.info.resource.realm && request->resource.resource == turn.info.resource.resource, "http-resource");
    if (!turn.bridge->local.caps.http_requests) fail(TRANSIT_SDK_UNSUPPORTED_CAPABILITY, "http-requests");
}
}
extern "C" {
transit_sdk_error transit_station_http_prepare(const transit_station_http_template *request, transit_sdk_bytes body, const transit_station_http_options *options, const char *native_directory, transit_station_http_request **out) {
    Uninterruptible guard; if (out) *out = nullptr;
    return boundary([&] {
        require(request && options && out, "http-prepare");
        counter(options->resource.realm); counter(options->resource.resource); counter(options->reconcile_before_ms);
        require(options->namespace_id && options->endpoint_revision && options->max_attempts, "http-request-identity");
        require(request->method >= TRANSIT_HTTP_GET && request->method <= TRANSIT_HTTP_OPTIONS, "http-method");
        require(request->header_count <= 64 && (request->headers || !request->header_count), "http-headers");
        auto prepared = std::make_unique<transit_station_http_request>();
        prepared->resource = options->resource; prepared->namespace_id = options->namespace_id; prepared->body = copy(body, 65536);
        const char *methods[] = {"GET", "HEAD", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"};
        std::string headers = "[";
        for (size_t i = 0; i < request->header_count; ++i) {
            if (i) headers += ',';
            const auto &header = request->headers[i];
            headers += "{\"name\":" + quote(text(header.name, 8192)) + ",\"value\":" + pieces(header.pieces, header.count) + "}";
            require(headers.size() <= TRANSIT_CLIENT_MAX_BODY, "http-headers-bound");
        }
        headers += ']';
        const auto action = "{\"prepare\":{\"resource\":" + decimal(options->resource.resource) + ",\"namespace\":" + quote(decimal(options->namespace_id)) +
            ",\"request\":{\"method\":" + quote(methods[request->method]) + ",\"target\":" + pieces(request->target, request->target_count) + ",\"headers\":" + headers +
            "},\"body\":" + quote(hex(prepared->body)) + ",\"endpoint_revision\":" + quote(decimal(options->endpoint_revision)) +
            ",\"reconcile_before_ms\":" + decimal(options->reconcile_before_ms) + ",\"max_attempts\":" + decimal(options->max_attempts) + "}}";
        Worker worker;
        worker.run([&] {
            Local local(native_directory); const auto value = codec(local, action);
            prepared->reference = unhex(local.raw.field(value, "prepared/reference", true), 112);
            prepared->metadata = unhex(local.raw.field(value, "prepared/metadata", true), 8192);
        });
        *out = prepared.release();
    });
}
transit_sdk_error transit_station_http_request_inspect(const transit_station_http_request *request, transit_station_http_request_view *out) {
    if (out) *out = {};
    return boundary([&] { require(request && out, "http-request"); *out = {request->resource, request->namespace_id, view(request->reference), view(request->metadata), view(request->body)}; });
}
void transit_station_http_request_destroy(transit_station_http_request *request) { delete request; }
transit_sdk_error transit_station_http_decode(uint64_t realm, transit_sdk_bytes bytes, const char *native_directory, transit_station_http_outcome *out) {
    Uninterruptible guard; if (out) *out = {};
    return boundary([&] {
        require(out, "http-outcome"); counter(realm); const auto action = "{\"outcome\":" + quote(hex(copy(bytes, 71))) + "}";
        Worker worker; transit_station_http_outcome decoded{};
        worker.run([&] {
            Local local(native_directory); const auto value = codec(local, action); const auto &raw = local.raw;
            if (exists(raw, value, "rejected")) {
                decoded.rejected = true; const auto reason = raw.field(value, "rejected", true);
                if (reason == "denied") decoded.rejection = TRANSIT_HTTP_DENIED;
                else if (reason == "invalid_request") decoded.rejection = TRANSIT_HTTP_INVALID_REQUEST;
                else if (reason == "busy") decoded.rejection = TRANSIT_HTTP_BUSY;
                else fail(TRANSIT_SDK_INCOMPATIBLE_NATIVE, "http-rejection");
                return;
            }
            const auto phase = raw.field(value, "outcome/phase", true);
            if (phase == "observed") decoded.phase = TRANSIT_HTTP_OBSERVED;
            else if (phase == "closed_unknown") decoded.phase = TRANSIT_HTTP_CLOSED_UNKNOWN;
            else if (phase == "not_dispatched") decoded.phase = TRANSIT_HTTP_NOT_DISPATCHED;
            else fail(TRANSIT_SDK_INCOMPATIBLE_NATIVE, "http-phase");
            decoded.resource = {realm, raw.number(value, "outcome/resource")}; decoded.exchange = wide(raw, value, "outcome/exchange");
            decoded.effect = raw.number(value, "outcome/effect", true); decoded.attempt = raw.number(value, "outcome/attempt", true);
            if (raw.field(value, "outcome/status") != "null") {
                const auto status = raw.number(value, "outcome/status");
                if (status < 200 || status > 599) fail(TRANSIT_SDK_INCOMPATIBLE_NATIVE, "http-status");
                decoded.status = static_cast<uint16_t>(status);
            }
            if (raw.field(value, "outcome/reference") != "null") {
                const auto reference = unhex(raw.field(value, "outcome/reference", true), sizeof(decoded.reference));
                decoded.reference_size = reference.size(); std::copy(reference.begin(), reference.end(), decoded.reference);
            }
        });
        *out = decoded;
    });
}
transit_sdk_error transit_station_turn_http_stage(transit_station_turn *turn, const transit_station_http_request *request, bool *ready) {
    if (ready) *ready = false;
    return with_turn(turn, false, [&](auto &owner) {
        require(ready, "http-stage"); request_scope(owner, request);
        const auto value = turn_apply(owner, "{\"http_stage\":{\"reference\":" + quote(hex(request->reference)) + ",\"metadata\":" + quote(hex(request->metadata)) + ",\"body\":" + quote(hex(request->body)) + "}}");
        *ready = owner.bridge->local.raw.boolean(value, "staged");
    });
}
transit_sdk_error transit_station_turn_http_call(transit_station_turn *turn, transit_sdk_process destination, const transit_station_http_request *request, uint64_t *correlation) {
    if (correlation) *correlation = 0;
    return with_turn(turn, false, [&](auto &owner) {
        require(correlation, "http-call"); request_scope(owner, request); peer(owner, destination);
        const auto value = turn_apply(owner, "{\"http_call\":{\"pid\":" + decimal(destination.pid) + ",\"reference\":" + quote(hex(request->reference)) + "}}");
        *correlation = wide(owner.bridge->local.raw, value, "correlation");
    });
}
}
