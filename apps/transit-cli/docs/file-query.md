# Query CSV and JSONL files

`transit file-query` runs a finite SQL query over explicitly named local files
or stdin on Linux x86_64. It captures the permitted bytes into private temporary
files, resolves a schema, and runs Fuze against that frozen content. It requires
no Transit installation, grants, credentials or network connection. Local OS
file access is the acquisition authority; this command creates no durable job.

```bash
transit file-query --format csv --mode full -c 'SELECT * FROM input' data.csv
transit file-query --format jsonl -c 'SELECT COUNT(*) FROM input' data.jsonl
gzip -c data.csv | transit file-query --format csv --gzip -c 'SELECT * FROM input' -
```

The source name is `input`. The query uses the
[finite file-plan profile](../../../packages/zig/transit-fuze/docs/file-sources.md#finite-file-plans):
projection, bounded NOT/AND/OR predicates, LIMIT, COUNT and checked int64 SUM. Logical values can
be projected recursively; comparison literals retain the existing six scalar
types without implicit casts. SQL does not open arbitrary paths or invoke a
file-reading function. Explicit acquisition options select the bytes.
An explicit source alias, such as `FROM input AS src`, binds qualified columns
to that alias and hides `input` as a qualifier. Aliases also work inside the
supported limited aggregate input. Bare aliases without `AS` are rejected.
Rows and aggregates accept explicit output names: `SELECT value AS amount FROM
input` or `SELECT SUM(value) AS total FROM input`. Result names must be distinct;
different names permit selecting one input more than once. Aliases preserve
values, types and states in JSON and Arrow output. SQL names have the same
16-byte identifier bound as native queries. WHERE uses original input names;
an outer aggregate uses the names of its inner projection. Output names are
part of plan identity, while source identity remains unchanged.

## Schemas and exact values

`--mode sampled` is the default, with a prefix bounded by 1024 records and 1 MiB.
`full` scans every source before execution; `explicit` requires `--schema PATH`;
`raw` preserves CSV fields as UTF-8 or JSONL records as JSON. Sampled/full modes
allow a partial schema override. Raw mode rejects overrides. The
[reader guide](../../../packages/zig/transit-fuze/docs/file-sources.md) defines
inference, empty/all-null inputs, sparse fields, name alignment and late errors.

Schema files contain the mandatory current logical type definition and a root
struct. For example, save this as `schema.json`:

```json
{
  "definition": "transit.fuze.types.v1.2026-09-30",
  "type": {
    "structure": [
      {"name": "id", "type": {"utf8": {}}},
      {"name": "amount", "type": {"decimal": {"precision": 20, "scale": 2}}, "nullable": true}
    ]
  }
}
```

```bash
transit file-query --format csv --mode explicit --schema schema.json \
  --null-token NULL -c 'SELECT * FROM input' data.csv
```

UTF-8 IDs preserve leading zeros. Decimal values use exact coefficients; they
do not select an application's monetary policy. Quoted `"NULL"` remains text;
only the unquoted configured token is null. CSV defaults to comma, double quotes,
a header and no null tokens. `--delimiter`, `--quote`, `--no-header` and one
`--null-token` override those rules. JSONL rejects CSV-specific options.
`--mismatch type_error` explicitly represents supported conversion failures;
framing errors, unknown fields and violated missing/null constraints still fail.

## Acquisition and limits

At most 128 paths are accepted. `-` reads stdin once; `--` ends option parsing.
Named paths must open as regular files; pipe other streams to stdin. Named
files start at byte zero; stdin starts at its inherited position. Capture checks
regular-file identity, size and modification/change times before/after reading.
It freezes the resulting bytes by SHA-256 and length. Changing the original path
after capture cannot change discovery or execution. Open descriptors remain the
local capability; chmod/unlink of the original path does not revoke a capture.

`TMPDIR` selects temporary storage, default `/tmp`. Captures are exclusive files
with mode 0600, unlinked immediately after creation. Bytes remain on disk while
their descriptors are open and are released when the command exits, including
process death. This is ephemeral capture, without crash recovery or replay.
Use disk-backed temporary storage when input exceeds the desired memory budget;
a tmpfs directory consumes that filesystem's memory allocation.

`--gzip` requires one gzip member per input. Header fields are bounded to 64 KiB;
optional header CRC, payload CRC32, expanded size and exact EOF are checked.
Concatenated members, trailing bytes, truncated input and invalid checksums fail
before schema output. Decoding uses the pinned Zig DEFLATE implementation.

| Option | Default and meaning |
| --- | --- |
| `--max-bytes` | 1 GiB total expanded captured bytes and each complete scan's work quota |
| `--max-encoded-bytes` | 1 GiB total acquired encoded bytes, including uncompressed inputs |
| `--sample-records` / `--sample-bytes` | 1024 records / 1 MiB, independent prefix bounds |
| `--max-records` | 100 million data records per complete scan |
| `--max-record-bytes` | 65536; can be lowered |
| `--max-fields` | 128; can be lowered |

Quotas are positive decimal integers. Expanded captures plus the current encoded
gzip capture bound spool usage by the two byte quotas; decompression never treats
a small compressed file as authority for unlimited expansion. Retained captures
scale with input size on disk. Resident acquisition uses fixed chunks, a DEFLATE
window and bounded metadata; discovery/execution release each row before the
next. Schema JSON is at most 64 KiB and output records at most 256 KiB. Total work
quotas may be increased explicitly; record, recursive type/value and field bounds
remain enforced. Disk exhaustion fails and releases captures.

## Output and completion

Stdout contains one JSON object per line: a header, zero or more row records,
then one completion record by default (`--output json`). Diagnostics use stderr. The header has mandatory
`definition: "transit.fuze.file-output.v1.2026-09-30"`, the output logical schema,
hex binding/plan commitments, and discovery evidence. Evidence `complete` says
whether discovery covered the full input; it is not query completion.

Each row is `{"row": CELL}` where CELL is a struct value from the
[neutral logical JSON contract](../../../contracts/FUZE_TYPES_V1.md#neutral-logical-json).
Integer/decimal/temporal payloads are exact decimal strings; floats retain their
IEEE bits. Null, missing and type error remain distinct. Consumers must validate
the header definition and schema rather than infer types from the JSON shapes.

The final `complete` object repeats the binding and plan and gives decimal-string
`scanned`/`emitted` counts. Ordinary rows are provisional until this record and a
successful exit. Every input row is validated, including columns/rows discarded
by projection, predicates or LIMIT. A late failure can leave a prefix on stdout;
it never emits completion. Cancellation or a broken downstream pipe can leave
an incomplete final JSON line. Aggregates appear only after source verification.

Successful completion/help returns 0, invalid invocation returns 2, runtime
failure returns 1, and SIGINT/SIGTERM cancellation returns 130. Cancellation is
checked while acquiring, decoding, scanning and waiting on stdin/stdout pipes.
It closes capture descriptors and does not cancel any remote work. There is no
automatic retry with changed bytes, hidden network fetch or retained result cache.

## Arrow output

`--output arrow` writes one binary Arrow IPC stream. It preserves every logical
type and cell state through the [logical Arrow profile](../../../contracts/FUZE_ARROW_V1.md),
including exact decimal coefficients, full-width integers, temporal units and
recursive values. Logical schema and frozen source/plan evidence accompany the
physical schema. Flight and native durable queries retain their own type profiles.

`--batch-rows 1..8` selects the maximum rows per batch, default 8. Batches split
when needed under the unchanged 4 MiB workspace and 64 KiB message-segment bounds.
A single oversized row or schema fails. Each row remains owned until its batch
is exported, so this mode retains at most eight rows. Require both successful
exit and the explicit IPC end marker: an Arrow reader may otherwise accept an
incomplete prefix as a stream. Cancellation/failure emits no successful end.
