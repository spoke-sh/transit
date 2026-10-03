# Connector admission rejection v1

HTTP `HTF1` and gRPC `GRF1` use the same 232-byte rejection layout, owned by
`transit-exchange`'s `AdmissionRejection`. All integers are little-endian and
there is no native padding. The shared native definition identifies this layout;
a five-byte rejection from another build is incompatible and fails decoding.
The [HTTP](STATION_HTTP_V1.md) and [gRPC](STATION_GRPC_V1.md) service contracts own
admission, follow-up and disposal semantics.

| Field | Type and bytes |
| --- | --- |
| magic | 4 bytes: HTF1 or GRF1 |
| reason | u8: denied=1, invalid_request=2, busy=3 |
| check | u8, described below |
| input | u64: original delivered service input position |
| request | 32-byte SHA-256 of that input's Station frame payload |
| field_len, field_truncated, field | u8, u8, 32 bytes |
| cause_len, cause_truncated, cause | u8, u8, 64 bytes |
| expected_kind, expected_number | u8, u64 |
| expected_len, expected_truncated, expected_text | u8, u8, 32 bytes |
| actual_kind, actual_number | u8, u64 |
| actual_len, actual_truncated, actual_text | u8, u8, 32 bytes |

The check values are unrecorded=0, decode=1, equal=2, maximum=3, different=4,
available=5, state=6, policy=7, occupied=8, mode=9 and before=10. `equal` and
`different` compare supplied and expected values; `maximum` permits supplied
values at or below the expected limit. `before` requires an observed time
strictly below the expected deadline. The other checks describe the failed
validation, availability, policy, state, occupancy or operation-mode gate.
They do not establish a previous exchange's outcome.

Scalar kinds are unrecorded=0, redacted=1, inapplicable=2, unsigned=3, text=4
and digest=5. Unsigned values use the number field with zero text storage.
Text uses its explicit byte length; digest uses all 32 bytes, length 32 and no
truncation. Other kinds require zero number/text storage. Non-number kinds
require a zero number. Every unused byte is zero. Text, field and cause strings
are valid UTF-8; truncation flags are exactly zero or one. Truncation never splits
a UTF-8 sequence. Non-UTF-8 caller bytes are rendered with a `bytes:` prefix and
hexadecimal byte escapes. Secret contents are never captured.

An unrecorded check requires empty field/cause storage and unrecorded scalar
kinds. A recorded check requires a nonempty field. An absent input is zero with
a zero request digest; a service-generated rejection records its actual delivered
input and payload commitment in the same fenced turn as the correlated reply.
The input position is not the service's commit position. Rejection does not
create a replacement exchange or authorize remote dispatch.

The reply itself retains the original witness. Later policy changes, parent
progress or disposal cannot replace it with a reconstructed explanation. The
caller receives it through the ordinary authenticated, durable Station reply
route. Input rejection remains separate from the existing exchange's outcome;
inspection guidance cannot imply rollback, cancellation or permission to retry
fresh work.

Caller-identity denials include the submitted caller with the configured caller
withheld. Operation-mode denials withhold the worker configuration.
Missing and foreign-caller parents share an unavailable-to-this-caller result.
Original parent values are disclosed only after checking the parent caller.
Credential values are withheld. Shared diagnostic projection uses `withheld`
for a redacted scalar, preserves explicit truncation and exposes numeric values
without JSON precision loss. `expected_value` and `supplied_value` carry the
comparison; `field_path` and `constraint` identify its meaning. The diagnostic
is excluded from telemetry and unrelated logs under the
[diagnostic disclosure contract](DIAGNOSTICS_V1.md#evidence-and-disclosure).

The scalar field bounds are independent of the 243-byte Station frame payload
bound. SDK reply codecs admit up to 232 bytes and delegate exact record length,
magic, enum, padding and semantic validation to the shared native implementation.

Follow-up validators retain original retry-key count, kind and length; captured
HTTP status/Location availability; redirect scope; and the first changed frozen
policy field. gRPC method, shape, descriptor and provenance comparisons retain
separate witnesses. Nested policy paths include list indexes and preserve bounded
truncation. Private routing, header, credential and target values are withheld by frozen-policy
comparison. The diagnostic walk runs only after canonical comparison fails; it
neither changes policy equality nor performs a later reconstruction.
