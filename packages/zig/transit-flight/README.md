# transit-flight

The Flight adapter serves finite Table queries through the current query v1
client, native signed operations and durable Station requester. It converts
verified result cells to primitive Arrow int64 columns, preserving null values
and full-width integers. Its published SQL supports projection, filters, limits,
count, checked sum and empty results. See the
[selected protocol](../../../contracts/FLIGHT_V1.md), [compatibility matrix](docs/compatibility.md)
and [codec guide](docs/codecs.md) for exact operations and bounds.
Errors retain standard gRPC status/message and a bounded `transit-diagnostic-bin`
application trailer with the shared semantic envelope. PyArrow middleware and
ADBC error details expose its JSON bytes under the current disclosure checks.

`proto/` contains Apache Arrow 23.0.0's Flight and Flight SQL definitions with
their original Apache-2.0 notices. `proto/manifest.json` records source URLs and
SHA-256 hashes. `generate.py` derives selected Zig wire declarations through
`protoc`; generated `src/Wire.zig` is separate from the public adapter. The
runtime uses the pinned native protobuf codec, without a protobuf compiler or
foreign Arrow runtime dependency. Regenerate with `nix develop .#flight --command
python3 packages/zig/transit-flight/generate.py`; add `--check` to detect drift.

Independent Python/C consumers use the pinned `flight` shell described in
[nix](../../../nix/README.md). Their standard Arrow/ADBC behavior must be proved
against this adapter, including metadata, before it is advertised as supported.
