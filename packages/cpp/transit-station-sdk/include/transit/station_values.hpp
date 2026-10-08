#pragma once
#include <transit/client.hpp>
#include <cstring>
namespace transit::sdk::station {
inline transit_sdk_error error_value(transit_sdk_error_kind kind, const char *phase) noexcept {
    transit_sdk_error value{}; value.kind = kind; std::strncpy(value.phase, phase, sizeof(value.phase) - 1); return value;
}
inline Error failure(transit_sdk_error_kind kind, const char *phase) { return Error(error_value(kind, phase)); }
template<class F> transit_sdk_error callback(F &&work) noexcept {
    try { work(); return {}; }
    catch (const Error &error) { return error.detail(); }
    catch (const std::bad_alloc &) { return error_value(TRANSIT_SDK_OUT_OF_MEMORY, "allocation"); }
    catch (...) { return error_value(TRANSIT_SDK_HANDLER_ERROR, "callback-exception"); }
}
inline Bytes copy_bytes(transit_sdk_bytes bytes) { return bytes.size ? Bytes(bytes.data, bytes.data + bytes.size) : Bytes{}; }
}
