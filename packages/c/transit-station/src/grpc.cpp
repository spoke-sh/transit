#include "internal.hpp"
using namespace transit::sdk::internal;
using namespace transit::sdk::station_detail;

namespace {
Bytes codec(Local &local, const std::string &action) {
    require(action.size() <= TRANSIT_CLIENT_MAX_BODY, "grpc-codec-bound");
    if (!local.caps.grpc_requests) fail(TRANSIT_SDK_UNSUPPORTED_CAPABILITY, "grpc-requests");
    station_buffer *buffer = nullptr;
    const auto status = local.station_grpc_codec(reinterpret_cast<const uint8_t *>(action.data()), action.size(), &buffer);
    return local.result(status, buffer, "grpc-codec");
}
void request_scope(const transit_station_turn &turn, const transit_station_grpc_request *request) {
    require(request && request->resource.realm == turn.info.resource.realm && request->resource.resource == turn.info.resource.resource, "grpc-resource");
    if (!turn.bridge->local.caps.grpc_requests) fail(TRANSIT_SDK_UNSUPPORTED_CAPABILITY, "grpc-requests");
}
}
extern "C" {
transit_sdk_error transit_station_grpc_method_bind(transit_sdk_bytes descriptor, const char *path, const char *native_directory, transit_station_grpc_method *out) {
    Uninterruptible guard; if (out) *out = {};
    return boundary([&] {
        require(out, "grpc-method");
        const auto action = "{\"descriptor\":{\"bytes\":" + quote(hex(copy(descriptor,65536))) + ",\"method\":" + quote(text(path,512)) + "}}";
        Worker worker; transit_station_grpc_method method{};
        worker.run([&] {
            Local local(native_directory); const auto value = codec(local,action);
            const auto name = local.raw.field(value,"descriptor/method/path",true);
            require(name.size() <= 512, "grpc-method-path"); std::copy(name.begin(),name.end(),method.path);
            const auto digest = unhex(local.raw.field(value,"descriptor/method/descriptor_digest",true),32);
            require(digest.size() == 32,"grpc-descriptor-digest"); std::copy(digest.begin(),digest.end(),method.descriptor_digest);
            const auto shape = local.raw.field(value,"descriptor/method/shape",true);
            const char *shapes[] = {"unary","server_streaming","client_streaming","bidi"};
            uint32_t index = 0; for (; index < 4 && shape != shapes[index]; ++index) {}
            require(index < 4,"grpc-method-shape"); method.shape = index;
        });
        *out = method;
    });
}
transit_sdk_error transit_station_grpc_prepare(const transit_station_grpc_template *request, const transit_sdk_bytes *messages, size_t message_count, const transit_station_grpc_options *options, const char *native_directory, transit_station_grpc_request **out) {
    Uninterruptible guard; if (out) *out = nullptr;
    return boundary([&] {
        require(request && options && out,"grpc-prepare");
        counter(options->resource.realm); counter(options->resource.resource); counter(options->reconcile_before_ms);
        require(options->namespace_id && options->endpoint_revision && options->max_attempts,"grpc-request-identity");
        require(request->method.shape <= TRANSIT_GRPC_BIDI,"grpc-shape");
        require(request->metadata_count <= 64 && (request->metadata || !request->metadata_count),"grpc-metadata");
        require(message_count <= 64 && (messages || !message_count),"grpc-messages");
        auto prepared = std::make_unique<transit_station_grpc_request>();
        prepared->resource = options->resource; prepared->namespace_id = options->namespace_id;
        std::string fields = "[";
        for (size_t i=0; i<request->metadata_count; ++i) {
            if (i) fields += ',';
            const auto &entry = request->metadata[i];
            fields += "{\"name\":" + quote(text(entry.name,8192)) + ",\"value\":";
            if (entry.secret) {
                require(entry.version != 0,"grpc-secret-version");
                fields += "{\"secret\":{\"binding\":" + quote(text(entry.binding,128)) + ",\"version\":" + quote(decimal(entry.version)) + "}}";
            } else fields += "{\"literal\":" + quote(hex(copy(entry.bytes,8192))) + "}";
            fields += '}'; require(fields.size() <= TRANSIT_CLIENT_MAX_BODY,"grpc-metadata-bound");
        }
        fields += ']';
        std::string batch = "[";
        for (size_t i=0; i<message_count; ++i) {
            if (i) batch += ','; batch += quote(hex(copy(messages[i],16384)));
            require(batch.size() <= TRANSIT_CLIENT_MAX_BODY,"grpc-message-bound");
        }
        batch += ']';
        const char *shapes[] = {"unary","server_streaming","client_streaming","bidi"};
        require(std::memchr(request->method.path,0,sizeof(request->method.path)),"grpc-method-path");
        const auto action = "{\"prepare\":{\"resource\":" + decimal(options->resource.resource) + ",\"namespace\":" + quote(decimal(options->namespace_id)) +
            ",\"request\":{\"method\":{\"path\":" + quote(text(request->method.path,512)) + ",\"shape\":" + quote(shapes[request->method.shape]) +
            ",\"descriptor_digest\":" + quote(hex(copy({request->method.descriptor_digest,32},32))) + "},\"metadata\":" + fields + "},\"messages\":" + batch +
            ",\"endpoint_revision\":" + quote(decimal(options->endpoint_revision)) + ",\"reconcile_before_ms\":" + decimal(options->reconcile_before_ms) + ",\"max_attempts\":" + decimal(options->max_attempts) + "}}";
        Worker worker; worker.run([&] {
            Local local(native_directory); const auto value = codec(local,action);
            prepared->reference = unhex(local.raw.field(value,"prepared/reference",true),145);
            prepared->metadata = unhex(local.raw.field(value,"prepared/metadata",true),8192);
            prepared->batch = unhex(local.raw.field(value,"prepared/batch",true),65544);
        });
        *out = prepared.release();
    });
}
transit_sdk_error transit_station_grpc_request_inspect(const transit_station_grpc_request *request, transit_station_grpc_request_view *out) {
    if (out) *out = {};
    return boundary([&] { require(request && out, "grpc-request"); *out = {request->resource, request->namespace_id, view(request->reference), view(request->metadata), view(request->batch)}; });
}
void transit_station_grpc_request_destroy(transit_station_grpc_request *request) { delete request; }
transit_sdk_error transit_station_grpc_decode(uint64_t realm, transit_sdk_bytes bytes, const char *native_directory, transit_station_grpc_outcome *out) {
    Uninterruptible guard; if (out) *out = {};
    return boundary([&] {
        require(out, "grpc-outcome"); counter(realm); const auto action = "{\"outcome\":" + quote(hex(copy(bytes, 73))) + "}";
        Worker worker; transit_station_grpc_outcome decoded{};
        worker.run([&] {
            Local local(native_directory); const auto value = codec(local, action); const auto &raw = local.raw;
            if (exists(raw, value, "rejected")) {
                decoded.rejected = true; const auto reason = raw.field(value, "rejected", true);
                if (reason == "denied") decoded.rejection = TRANSIT_GRPC_DENIED;
                else if (reason == "invalid_request") decoded.rejection = TRANSIT_GRPC_INVALID_REQUEST;
                else if (reason == "busy") decoded.rejection = TRANSIT_GRPC_BUSY;
                else fail(TRANSIT_SDK_INCOMPATIBLE_NATIVE, "grpc-rejection");
                return;
            }
            const auto phase = raw.field(value, "outcome/phase", true);
            if (phase == "observed") decoded.phase = TRANSIT_GRPC_OBSERVED;
            else if (phase == "closed_unknown") decoded.phase = TRANSIT_GRPC_CLOSED_UNKNOWN;
            else if (phase == "not_dispatched") decoded.phase = TRANSIT_GRPC_NOT_DISPATCHED;
            else fail(TRANSIT_SDK_INCOMPATIBLE_NATIVE, "grpc-phase");
            decoded.resource = {realm, raw.number(value, "outcome/resource")}; decoded.exchange = wide(raw, value, "outcome/exchange");
            decoded.effect = raw.number(value, "outcome/effect", true); decoded.attempt = raw.number(value, "outcome/attempt", true);
            if (raw.field(value, "outcome/status") != "null") {
                const auto status = raw.number(value, "outcome/status", true);
                if (status > 16) fail(TRANSIT_SDK_INCOMPATIBLE_NATIVE, "grpc-status");
                decoded.status = static_cast<uint32_t>(status); decoded.has_status = true;
            }
            if (raw.field(value, "outcome/reference") != "null") {
                const auto reference = unhex(raw.field(value, "outcome/reference", true), sizeof(decoded.reference));
                decoded.reference_size = reference.size(); std::copy(reference.begin(), reference.end(), decoded.reference);
            }
        });
        *out = decoded;
    });
}
transit_sdk_error transit_station_grpc_decode_released(uint64_t realm, transit_sdk_bytes bytes, const char *native_directory, transit_station_grpc_released *out) {
    Uninterruptible guard; if (out) *out = {};
    return boundary([&] {
        require(out, "grpc-released"); counter(realm);
        const auto action = "{\"released\":" + quote(hex(copy(bytes, 20))) + "}";
        Worker worker; transit_station_grpc_released decoded{};
        worker.run([&] {
            Local local(native_directory);
            if (!local.caps.grpc_release) fail(TRANSIT_SDK_UNSUPPORTED_CAPABILITY, "grpc-release");
            const auto value = codec(local, action);
            decoded.resource = {realm, local.raw.number(value, "released/resource")};
            decoded.exchange = wide(local.raw, value, "released/exchange");
        });
        *out = decoded;
    });
}
transit_sdk_error transit_station_turn_grpc_stage(transit_station_turn *turn, const transit_station_grpc_request *request, bool *ready) {
    if (ready) *ready = false;
    return with_turn(turn, false, [&](auto &owner) {
        require(ready, "grpc-stage"); request_scope(owner, request);
        const auto value = turn_apply(owner, "{\"grpc_stage\":{\"reference\":" + quote(hex(request->reference)) + ",\"metadata\":" + quote(hex(request->metadata)) + ",\"batch\":" + quote(hex(request->batch)) + "}}");
        *ready = owner.bridge->local.raw.boolean(value, "staged");
    });
}
transit_sdk_error transit_station_turn_grpc_call(transit_station_turn *turn, transit_sdk_process destination, const transit_station_grpc_request *request, uint64_t *correlation) {
    if (correlation) *correlation = 0;
    return with_turn(turn, false, [&](auto &owner) {
        require(correlation, "grpc-call"); request_scope(owner, request); peer(owner, destination);
        const auto value = turn_apply(owner, "{\"grpc_call\":{\"pid\":" + decimal(destination.pid) + ",\"reference\":" + quote(hex(request->reference)) + "}}");
        *correlation = wide(owner.bridge->local.raw, value, "correlation");
    });
}
transit_sdk_error transit_station_turn_grpc_release(transit_station_turn *turn, transit_sdk_process destination, transit_sdk_resource capture, uint64_t exchange, uint64_t *correlation) {
    if (correlation) *correlation = 0;
    return with_turn(turn, false, [&](auto &owner) {
        require(correlation && exchange && capture.realm == owner.info.resource.realm, "grpc-release-identity");
        counter(capture.resource); peer(owner, destination);
        if (!owner.bridge->local.caps.grpc_release) fail(TRANSIT_SDK_UNSUPPORTED_CAPABILITY, "grpc-release");
        const auto value = turn_apply(owner, "{\"grpc_release\":{\"pid\":" + decimal(destination.pid) + ",\"resource\":" + decimal(capture.resource) + ",\"exchange\":" + quote(decimal(exchange)) + "}}");
        *correlation = wide(owner.bridge->local.raw, value, "correlation");
    });
}
transit_sdk_error transit_station_turn_grpc_retry(transit_station_turn *turn, transit_sdk_process destination, const transit_station_grpc_outcome *parent, const transit_station_grpc_request *request, uint64_t *correlation) {
    if (correlation) *correlation = 0;
    return with_turn(turn, false, [&](auto &owner) {
        require(correlation && parent && !parent->rejected && parent->exchange && parent->resource.realm == owner.info.resource.realm, "grpc-followup-identity");
        counter(parent->resource.resource); request_scope(owner, request); peer(owner, destination);
        if (!owner.bridge->local.caps.grpc_followup) fail(TRANSIT_SDK_UNSUPPORTED_CAPABILITY, "grpc-followup");
        const auto value = turn_apply(owner, "{\"grpc_followup\":{\"pid\":" + decimal(destination.pid) + ",\"resource\":" + decimal(parent->resource.resource) + ",\"parent\":" + quote(decimal(parent->exchange)) + ",\"reference\":" + quote(hex(request->reference)) + "}}");
        *correlation = wide(owner.bridge->local.raw, value, "correlation");
    });
}
}
