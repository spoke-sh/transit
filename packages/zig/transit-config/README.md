# transit-config

Shared Zig configuration input and domain-owned typed setting descriptions.
The package depends on the standard library and public Transit protocol. Component owners supply their
descriptors, defaults, cross-field validation and application lifecycle.

`Input` owns bounded YAML/JSON input, typed environment overlays and file
selection. `Registry` owns canonical keys, value kinds, units, bounds, source
metadata and explicit scope/change policies. Parsing and normalization do not
grant authority or apply changes. Callers supply an arena and retain values only
for that arena's lifetime.

Configuration input is limited to 64 KiB, 96 nested containers and 65,536 syntax
nodes. YAML accepts block mappings and sequences (including mapping entries),
plain/single-quoted strings and JSON flow values with trailing comments. It
rejects duplicate keys, anchors, aliases, tags, merge keys, multiline scalars and
multiple documents. Exact integer durations use ms/s/min/h; byte sizes use B,
KiB/MiB/GiB or kB/MB/GB. Unspecified units in string quantities reject.

From the pinned development shell:

```sh
cd packages/zig/transit-config
zig build test
```

The repository package test/check tasks also include this package.

The public [configuration contract](../../../contracts/CONFIGURATION_V1.md) binds
requests to current native authority. The package owns input, descriptors and
envelopes; hosts own file I/O checkpoints and live application.
