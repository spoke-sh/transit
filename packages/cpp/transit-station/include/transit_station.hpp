#pragma once
#include <transit_station.h>
#include <transit_client.h>
#include <array>
#include <cstdint>
#include <memory>
#include <stdexcept>
#include <string>
#include <string_view>
#include <utility>

namespace transit {
class Error : public std::runtime_error {
public:
    std::uint32_t status;
    explicit Error(std::uint32_t code, const std::string& detail = {})
        : std::runtime_error("Transit status " + std::to_string(code) + ": " + detail), status(code) {}
};
inline const std::uint8_t* bytes(std::string_view value) {
    return reinterpret_cast<const std::uint8_t*>(value.data());
}
class Buffer {
    station_buffer* value_ = nullptr;
public:
    explicit Buffer(station_buffer* value = nullptr) : value_(value) {}
    ~Buffer() { station_buffer_destroy(value_); }
    Buffer(const Buffer&) = delete;
    Buffer& operator=(const Buffer&) = delete;
    Buffer(Buffer&& other) noexcept : value_(std::exchange(other.value_, nullptr)) {}
    Buffer& operator=(Buffer&& other) noexcept {
        if (this != &other) { station_buffer_destroy(value_); value_ = std::exchange(other.value_, nullptr); }
        return *this;
    }
    std::string_view view() const {
        if (!value_) return {};
        return {reinterpret_cast<const char*>(station_buffer_data(value_)), station_buffer_size(value_)};
    }
};
inline Buffer checked(std::uint32_t status, station_buffer* result) {
    Buffer value(result);
    if (status) throw Error(status, std::string(value.view()));
    return value;
}
inline Buffer field(std::string_view json, std::string_view path, bool raw_string = false) {
    station_buffer* value = nullptr;
    auto status = station_json_extract(bytes(json), json.size(), bytes(path), path.size(), raw_string, &value);
    return checked(status, value);
}
class GenServer {
    station_server* value_ = nullptr;
public:
    GenServer(std::string_view url, const std::array<std::uint8_t, 32>& seed, std::string_view config) {
        auto status = station_server_create(STATION_ABI_VERSION, bytes(url), url.size(), seed.data(), bytes(config), config.size(), &value_);
        if (status) throw Error(status);
    }
    ~GenServer() { station_server_destroy(value_); }
    GenServer(const GenServer&) = delete;
    GenServer& operator=(const GenServer&) = delete;
    GenServer(GenServer&& other) noexcept : value_(std::exchange(other.value_, nullptr)) {}
    GenServer& operator=(GenServer&&) = delete;
    Buffer next(std::uint64_t deadline_ms) {
        if (!value_) throw Error(STATION_STATUS_INVALID_ARGUMENT, "Moved handle");
        station_buffer* result = nullptr;
        auto status = station_server_next(value_, deadline_ms, &result);
        return checked(status, result);
    }
    Buffer apply(std::string_view action) {
        if (!value_) throw Error(STATION_STATUS_INVALID_ARGUMENT, "Moved handle");
        station_buffer* result = nullptr;
        auto status = station_server_apply(value_, bytes(action), action.size(), &result);
        return checked(status, result);
    }
    void finish(bool failed = false) {
        if (!value_) throw Error(STATION_STATUS_INVALID_ARGUMENT, "Moved handle");
        auto status = station_server_finish(value_, failed);
        if (status) throw Error(status);
    }
    Buffer pending() {
        if (!value_) throw Error(STATION_STATUS_INVALID_ARGUMENT, "Moved handle");
        station_buffer* result = nullptr;
        auto status = station_server_pending(value_, &result);
        return checked(status, result);
    }
};
inline Buffer arrow_cell(std::string_view ipc, std::uint32_t row, std::uint32_t column) {
    station_buffer* result = nullptr;
    auto status = station_arrow_cell(bytes(ipc), ipc.size(), row, column, &result);
    return checked(status, result);
}
// Raw Transit handles stay separate: no Station behavior is required to use them.
class Client {
    transit_client* value_ = nullptr;
public:
    explicit Client(std::string_view url, std::uint32_t timeout_ms = 5000) {
        auto status = transit_client_create(TRANSIT_CLIENT_ABI_VERSION, bytes(url), url.size(), timeout_ms, &value_);
        if (status) throw Error(status);
    }
    ~Client() { transit_client_destroy(value_); }
    Client(const Client&) = delete;
    Client& operator=(const Client&) = delete;
    static std::string prepare(std::uint32_t kind, const std::array<std::uint8_t, 32>& seed, std::string_view json) {
        transit_operation* pointer = nullptr;
        auto status = transit_operation_prepare(kind, seed.data(), bytes(json), json.size(), &pointer);
        std::unique_ptr<transit_operation, decltype(&transit_operation_destroy)> operation(pointer, transit_operation_destroy);
        if (status) throw Error(status);
        transit_buffer* buffer = nullptr;
        status = transit_operation_export(operation.get(), &buffer);
        std::unique_ptr<transit_buffer, decltype(&transit_buffer_destroy)> result(buffer, transit_buffer_destroy);
        if (status) throw Error(status);
        return {reinterpret_cast<const char*>(transit_buffer_data(result.get())), transit_buffer_size(result.get())};
    }
    std::string call(std::string_view frozen) {
        transit_operation* operation = nullptr;
        auto status = transit_operation_import(bytes(frozen), frozen.size(), &operation);
        if (status) throw Error(status);
        transit_buffer* response = nullptr;
        status = transit_client_call(value_, operation, &response);
        transit_operation_destroy(operation);
        try {
            std::string result = response ? std::string(reinterpret_cast<const char*>(transit_buffer_data(response)), transit_buffer_size(response)) : "";
            transit_buffer_destroy(response);
            response = nullptr;
            if (status) throw Error(status, result);
            return result;
        } catch (...) {
            transit_buffer_destroy(response);
            throw;
        }
    }
};
} // namespace transit
