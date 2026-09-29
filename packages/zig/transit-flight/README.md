# transit-flight

The [M22](../../../docs/internal/roadmap/M22.md) Flight adapter implements a qualified finite profile.
The selected profile is the public finite Table query v1 with primitive int64
columns, using the existing Fuze SQL compiler and durable Station query identity.
Pinned PyArrow independently validates the metadata IPC, optional filters,
empty batches, published Table schema and all six union children. Native TLS
queries pass PyArrow and pinned ADBC C/Python checks, including empty/aggregate
results and exact retry. Native adversarial lifecycle/load, recorded outbound
replay and Compose/reference physical recovery also pass. See the
[selected protocol](../../../contracts/FLIGHT_V1.md), [compatibility matrix](docs/compatibility.md)
and [codec guide](docs/codecs.md).

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
