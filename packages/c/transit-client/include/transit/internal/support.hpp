#pragma once
// Exact-version package interface for the Station SDK. Not a public wire API.
#include <transit/client.h>
#include <transit_client.h>
#include <algorithm>
#include <array>
#include <condition_variable>
#include <cstring>
#include <exception>
#include <functional>
#include <memory>
#include <mutex>
#include <pthread.h>
#include <string>
#include <vector>

namespace transit::sdk::internal {
using Bytes = std::vector<uint8_t>;
struct Failure { transit_sdk_error value; };
inline transit_sdk_error error(transit_sdk_error_kind kind, const char *phase) noexcept {
    transit_sdk_error result{}; result.kind = kind;
    std::strncpy(result.phase, phase, sizeof(result.phase) - 1); return result;
}
[[noreturn]] inline void fail(transit_sdk_error_kind kind, const char *phase) { throw Failure{error(kind, phase)}; }
inline void require(bool yes, const char *phase) { if (!yes) fail(TRANSIT_SDK_INVALID_ARGUMENT, phase); }
inline void counter(uint64_t value, bool zero = false) { require(value <= TRANSIT_CLIENT_MAX_COUNTER && (zero || value), "counter"); }
inline void process(transit_sdk_process value) { counter(value.realm); counter(value.pid); }
inline std::string text(const char *value, size_t bound = TRANSIT_CLIENT_MAX_BODY) {
    require(value != nullptr, "string"); const auto length = strnlen(value, bound + 1);
    require(length <= bound, "string-bound"); return std::string(value, length);
}
inline Bytes copy(transit_sdk_bytes value, size_t bound = TRANSIT_CLIENT_MAX_BODY) {
    require(value.size <= bound && (value.data || !value.size), "byte-bound");
    return value.size ? Bytes(value.data, value.data + value.size) : Bytes{};
}
inline transit_sdk_bytes view(const Bytes &value) { return {value.data(), value.size()}; }
inline transit_sdk_buffer owned(const Bytes &value) {
    std::unique_ptr<uint8_t[]> data(new uint8_t[value.size()]);
    std::copy(value.begin(), value.end(), data.get()); return {data.release(), value.size()};
}
// Deferred cancellation covers acquisition, native I/O and output publication.
// Callers may abandon a separate controlling wait, then join their owned task.
class Uninterruptible {
    int previous;
public:
    Uninterruptible() { pthread_setcancelstate(PTHREAD_CANCEL_DISABLE, &previous); }
    ~Uninterruptible() noexcept(false) { pthread_setcancelstate(previous, nullptr); }
    Uninterruptible(const Uninterruptible &) = delete;
};
template<class F> transit_sdk_error boundary(F &&work) noexcept {
    try { work(); return {}; }
    catch (const Failure &failure) { return failure.value; }
    catch (const std::bad_alloc &) { return error(TRANSIT_SDK_OUT_OF_MEMORY, "allocation"); }
    catch (...) { return error(TRANSIT_SDK_HANDLER_ERROR, "foreign-exception"); }
}
class Worker {
    pthread_t thread{};
    std::mutex mutex;
    std::condition_variable changed;
    std::function<void()> *job = nullptr;
    std::exception_ptr failure;
    bool busy = false, done = false, stopping = false, closing = false, closed = false;
    static void *entry(void *pointer) noexcept {
        auto &self = *static_cast<Worker *>(pointer);
        pthread_setcancelstate(PTHREAD_CANCEL_DISABLE, nullptr);
        std::unique_lock<std::mutex> lock(self.mutex);
        for (;;) {
            self.changed.wait(lock, [&] { return self.job || self.stopping; });
            if (self.stopping) break;
            auto *job = self.job; self.job = nullptr;
            lock.unlock();
            try { (*job)(); } catch (...) { self.failure = std::current_exception(); }
            lock.lock(); self.done = true; self.changed.notify_all();
        }
        return nullptr;
    }
public:
    Worker() {
        pthread_attr_t attr;
        if (pthread_attr_init(&attr)) fail(TRANSIT_SDK_READ_FAILED, "worker-attributes");
        int status = pthread_attr_setstacksize(&attr, TRANSIT_CLIENT_MINIMUM_STACK_BYTES);
        if (!status) status = pthread_create(&thread, &attr, entry, this);
        pthread_attr_destroy(&attr);
        if (status) fail(TRANSIT_SDK_READ_FAILED, "worker-create");
    }
    Worker(const Worker &) = delete;
    void check_close() {
        std::lock_guard<std::mutex> lock(mutex);
        if (!closed && pthread_equal(pthread_self(), thread)) fail(TRANSIT_SDK_BUSY, "worker-reentry");
    }
    void run(std::function<void()> work) {
        std::unique_lock<std::mutex> lock(mutex);
        if (closing || closed) fail(TRANSIT_SDK_CLOSED, "worker");
        if (pthread_equal(pthread_self(), thread)) fail(TRANSIT_SDK_BUSY, "worker-reentry");
        if (busy) fail(TRANSIT_SDK_BUSY, "worker");
        busy = true; done = false; failure = nullptr; job = &work; changed.notify_all();
        changed.wait(lock, [&] { return done; });
        const auto problem = failure; failure = nullptr; busy = false; changed.notify_all();
        lock.unlock(); if (problem) std::rethrow_exception(problem);
    }
    void close(std::function<void()> cleanup) {
        std::unique_lock<std::mutex> lock(mutex);
        if (closed) return;
        if (pthread_equal(pthread_self(), thread)) fail(TRANSIT_SDK_BUSY, "worker-reentry");
        if (closing) { changed.wait(lock, [&] { return closed; }); return; }
        closing = true; changed.wait(lock, [&] { return !busy; });
        failure = nullptr; done = false; job = &cleanup; changed.notify_all();
        changed.wait(lock, [&] { return done; });
        const auto problem = failure; failure = nullptr; stopping = true; changed.notify_all();
        lock.unlock(); pthread_join(thread, nullptr); lock.lock(); closed = true; changed.notify_all();
        lock.unlock(); if (problem) std::rethrow_exception(problem);
    }
    ~Worker() { close([] {}); }
};
class Library {
    void *handle = nullptr;
public:
    Library(const char *directory, const char *name);
    ~Library();
    Library(const Library &) = delete;
    void *symbol(const char *name) const;
};
#define TRANSIT_RAW_FUNCTIONS(X) \
    X(transit_client_abi_version) X(transit_client_supports_kind) X(transit_json_extract) \
    X(transit_client_create) X(transit_client_destroy) X(transit_operation_prepare) \
    X(transit_operation_export) X(transit_operation_metadata) X(transit_operation_import) \
    X(transit_operation_destroy) X(transit_client_call) X(transit_buffer_data) \
    X(transit_buffer_size) X(transit_buffer_destroy)
class Raw {
    Library library;
public:
#define DECLARE(name) decltype(&::name) name;
    TRANSIT_RAW_FUNCTIONS(DECLARE)
#undef DECLARE
    explicit Raw(const char *directory);
    Bytes take(transit_buffer *buffer) const;
    std::string field(const Bytes &json, const std::string &path, bool raw = false) const;
    uint64_t number(const Bytes &json, const std::string &path, bool zero = false, bool quoted = false) const;
    bool boolean(const Bytes &json, const std::string &path) const;
    transit_sdk_error native_error(uint32_t status, const Bytes &json, const char *phase) const;
    void check(uint32_t status, const Bytes &json, const char *phase) const;
    Bytes metadata(const Bytes &bytes) const;
    transit_sdk_mutation_info info(const Bytes &bytes) const;
    Bytes prepare(uint32_t kind, const transit_sdk_credential &credential, const std::string &json) const;
    Bytes call(transit_client *client, const Bytes &bytes, bool mutation) const;
};
std::string hex(const Bytes &bytes);
Bytes unhex(const std::string &value, size_t bound);
std::string quote(const std::string &value);
void credential(const transit_sdk_credential &value);
class Seed {
    std::array<uint8_t, 32> bytes{};
public:
    explicit Seed(const char *path);
    ~Seed();
    const uint8_t *data() const { return bytes.data(); }
};
}
