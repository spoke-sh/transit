# Independent RPC descriptor fixture

`peer.proto` describes the four call shapes and the binary/Unicode/full-width
payload used by the independent transport peer. `peer.pb` is protoc 34.1's
FileDescriptorSet with imports. `tests/grpc_transport.py` regenerates it and
requires identical bytes, then uses Python protobuf to construct the reference
payload independently of Zig's codec. Neither reflection nor a live schema
lookup is used. Additional hostile peer methods use raw envelopes deliberately.

Regenerate inside `nix develop`:

```sh
protoc --proto_path=tests/fixtures/grpc --include_imports \
  --descriptor_set_out=tests/fixtures/grpc/peer.pb tests/fixtures/grpc/peer.proto
```
