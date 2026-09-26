#pragma once
#include <transit/client.h>
#include <memory>
#include <stdexcept>
#include <string>
#include <utility>
#include <variant>
#include <vector>

namespace transit::sdk {
using Bytes = std::vector<uint8_t>;
using Capabilities = transit_sdk_capabilities;
using AdmissionReceipt = transit_sdk_admission;
using MutationReceipt = transit_sdk_confirmation;
using Shutdown = transit_sdk_shutdown;
using MutationInfo = transit_sdk_mutation_info;
using SendInfo = transit_sdk_send_info;
class Error : public std::runtime_error {
    transit_sdk_error detail_;
public:
    explicit Error(transit_sdk_error value) : std::runtime_error(
        std::string("Transit error during ") + value.phase + (value.kind == TRANSIT_SDK_INCOMPATIBLE_NATIVE ?
        "; install the matching native 0.2.0 artifact or supply its directory" : "")), detail_(value) {}
    const transit_sdk_error &detail() const noexcept { return detail_; }
};
inline void check(transit_sdk_error result) { if (result.kind != TRANSIT_SDK_OK) throw Error(result); }
inline std::string checked_string(std::string value) {
    if (value.find('\0') != std::string::npos) {
        transit_sdk_error error{}; error.kind = TRANSIT_SDK_INVALID_ARGUMENT; throw Error(error);
    }
    return value;
}
inline transit_sdk_bytes bytes_view(const Bytes &value) { return {value.data(), value.size()}; }
class Buffer {
    transit_sdk_buffer value_{};
public:
    explicit Buffer(transit_sdk_buffer value) : value_(value) {}
    ~Buffer() { transit_sdk_buffer_release(&value_); }
    Buffer(const Buffer &) = delete;
    Buffer(Buffer &&other) noexcept : value_(std::exchange(other.value_, {})) {}
    Bytes copy() const { return value_.size ? Bytes(value_.data, value_.data + value_.size) : Bytes{}; }
};
class ProcessRef {
    transit_sdk_process value_;
public:
    ProcessRef(uint64_t realm, uint64_t pid) { check(transit_sdk_process_make(realm, pid, &value_)); }
    uint64_t realm() const { return value_.realm; }
    uint64_t pid() const { return value_.pid; }
    transit_sdk_process native() const { return value_; }
};
class ResourceRef {
    transit_sdk_resource value_;
public:
    ResourceRef(uint64_t realm, uint64_t resource) { check(transit_sdk_resource_make(realm, resource, &value_)); }
    uint64_t realm() const { return value_.realm; }
    uint64_t resource() const { return value_.resource; }
    transit_sdk_resource native() const { return value_; }
};
class Credential {
    uint64_t realm_, principal_;
    std::string seed_file_;
public:
    Credential(uint64_t realm, uint64_t principal, std::string seed_file)
        : realm_(realm), principal_(principal), seed_file_(checked_string(std::move(seed_file))) {}
    transit_sdk_credential native() const { return {realm_, principal_, seed_file_.c_str()}; }
};
class ClientConfig {
    std::string url_, directory_;
    uint32_t timeout_ = 30000;
    explicit ClientConfig(std::string url) : url_(checked_string(std::move(url))) {}
public:
    static ClientConfig growing(std::string url) { return ClientConfig(std::move(url)); }
    ClientConfig &timeout(uint32_t milliseconds) { timeout_ = milliseconds; return *this; }
    ClientConfig &native_directory(std::string directory) { directory_ = checked_string(std::move(directory)); return *this; }
    transit_sdk_config native() const {
        auto value = transit_sdk_growing_config(url_.c_str()); value.timeout_ms = timeout_;
        value.native_directory = directory_.empty() ? nullptr : directory_.c_str(); return value;
    }
};
class PendingSend {
    friend class Client;
    std::unique_ptr<transit_sdk_pending_send, decltype(&transit_sdk_pending_send_destroy)> value_;
    explicit PendingSend(transit_sdk_pending_send *value) : value_(value, transit_sdk_pending_send_destroy) {}
public:
    PendingSend(PendingSend &&) noexcept = default;
    PendingSend &operator=(PendingSend &&) noexcept = default;
    SendInfo info() const { SendInfo result{}; check(transit_sdk_pending_send_info(value_.get(), &result)); return result; }
    Bytes export_bytes() const {
        transit_sdk_buffer result{}; check(transit_sdk_pending_send_export(value_.get(), &result)); return Buffer(result).copy();
    }
};
class PendingMutation {
    friend class Client;
    std::unique_ptr<transit_sdk_pending_mutation, decltype(&transit_sdk_pending_mutation_destroy)> value_;
    explicit PendingMutation(transit_sdk_pending_mutation *value) : value_(value, transit_sdk_pending_mutation_destroy) {}
public:
    PendingMutation(PendingMutation &&) noexcept = default;
    PendingMutation &operator=(PendingMutation &&) noexcept = default;
    MutationInfo info() const { MutationInfo result{}; check(transit_sdk_pending_mutation_info(value_.get(), &result)); return result; }
    Bytes export_bytes() const {
        transit_sdk_buffer result{}; check(transit_sdk_pending_mutation_export(value_.get(), &result)); return Buffer(result).copy();
    }
};
struct Rejected { Error cause; };
struct PreflightFailed { Error cause; };
struct Uncertain { Error cause; Bytes recovery; };
template<class Receipt> using Dispatch = std::variant<Receipt, Rejected, PreflightFailed, Uncertain>;
class Client {
    std::unique_ptr<transit_sdk_client, decltype(&transit_sdk_client_destroy)> value_;
    explicit Client(transit_sdk_client *value) : value_(value, transit_sdk_client_destroy) {}
    template<class Receipt, class Pending> static Dispatch<Receipt> outcome(transit_sdk_dispatch value, const Pending &pending) {
        switch (value.outcome) {
            case TRANSIT_SDK_ADMITTED: case TRANSIT_SDK_CONFIRMED: return Receipt{value.position};
            case TRANSIT_SDK_DISPATCH_REJECTED: return Rejected{Error(value.error)};
            case TRANSIT_SDK_UNCERTAIN: return Uncertain{Error(value.error), pending.export_bytes()};
            default: return PreflightFailed{Error(value.error)};
        }
    }
public:
    Client(Client &&) noexcept = default;
    Client &operator=(Client &&) noexcept = default;
    static Client open(const ClientConfig &config) {
        const auto settings = config.native(); transit_sdk_client *value = nullptr;
        check(transit_sdk_client_open(&settings, &value)); return Client(value);
    }
    Capabilities capabilities(const Credential &credential) {
        Capabilities value{}; const auto identity = credential.native();
        check(transit_sdk_client_capabilities(value_.get(), &identity, &value)); return value;
    }
    PendingSend prepare_send(ProcessRef peer, const Bytes &value, const Credential &credential, uint64_t sequence) {
        transit_sdk_pending_send *pending = nullptr; const auto identity = credential.native();
        check(transit_sdk_client_prepare_send(value_.get(), peer.native(), bytes_view(value), &identity, sequence, &pending)); return PendingSend(pending);
    }
    PendingSend recover_send(const Bytes &bytes) {
        transit_sdk_pending_send *pending = nullptr; check(transit_sdk_client_recover_send(value_.get(), bytes_view(bytes), &pending)); return PendingSend(pending);
    }
    PendingMutation recover_mutation(const Bytes &bytes) {
        transit_sdk_pending_mutation *pending = nullptr; check(transit_sdk_client_recover_mutation(value_.get(), bytes_view(bytes), &pending)); return PendingMutation(pending);
    }
    Dispatch<AdmissionReceipt> dispatch(const PendingSend &pending) {
        return outcome<AdmissionReceipt>(transit_sdk_client_dispatch(value_.get(), pending.value_.get()), pending);
    }
    Dispatch<MutationReceipt> dispatch(const PendingMutation &pending) {
        return outcome<MutationReceipt>(transit_sdk_client_dispatch_mutation(value_.get(), pending.value_.get()), pending);
    }
    Shutdown close() { Shutdown result{}; check(transit_sdk_client_close(value_.get(), &result)); return result; }
};
}
