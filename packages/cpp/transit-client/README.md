# Transit public C++ client

`transit/client.hpp` provides C++17 value types, move-only clients/pending handles,
owned byte vectors and variant dispatch outcomes over the independent
[C SDK](../../c/transit-client/README.md). This is separate from M9's
`transit_station.hpp` wrappers. Its namespace is `transit::sdk`.

Install the C, native and C++ archives from `just bindings::c-build` into one
prefix. Compile with `zig c++ -std=c++17 app.cpp $(pkg-config --cflags --libs
transit-client-cpp)`. The package manifest pins its direct C SDK dependency;
pkg-config enforces the installed version. No sibling-source imports or manual
native loader paths are needed. The pinned Zig C++ ABI and Nix Linux x86_64
closure are the qualified combination.

```cpp
auto client = transit::sdk::Client::open(transit::sdk::ClientConfig::growing(url));
auto pending = client.prepare_send(peer, encoded_message, credential, sequence);
persist(pending.export_bytes()); // application-owned durable recovery store
auto outcome = client.dispatch(pending);
if (auto *receipt = std::get_if<transit::sdk::AdmissionReceipt>(&outcome)) {
    observe_admission(receipt->position);
}
```

`Rejected`, `PreflightFailed` and `Uncertain` are the other outcomes. Uncertain
includes owned retry bytes. Other operations throw `Error`, preserving the C
error's category, phase, native status and bounded code. Pending handles also
retain their bytes if allocating a convenience result fails. `close()` joins
work and returns last known receipts; RAII releases all native resources.
Destructors never commit or imply cancellation. [C ownership rules](../../c/transit-client/docs/USAGE.md)
also apply: do not move or destroy a C++ object while another thread uses it.
The client can be moved into one application-owned blocking task; an async
controller can abandon its receive and later join that task.

`just bindings::c-sdk-test` compiles installed C and C++ consumers independently,
checks move-only types and runs each through the shared real-authority schedule.
