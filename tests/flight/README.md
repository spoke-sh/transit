# Independent ADBC C consumer

`adbc.h` is the unchanged Apache ADBC release 24 public header, with its original
Apache-2.0 notice. `upstream.json` pins its URL and SHA-256. The C program loads
the same pinned Flight SQL 1.12.0 driver used by the Python consumer through its
standard driver vtable and Arrow C Stream interface. It verifies schema, exact
int64/null rows and explicit release of every array/schema/stream and ADBC handle.
The credential is read from a private file, never passed in command arguments.

The native gateway/query engine links none of these C/Go/Python client runtimes.
See the [M22 proof ledger](../README.md#m22-qualification) for current
qualification status; compiling this consumer alone is not interoperability proof.
