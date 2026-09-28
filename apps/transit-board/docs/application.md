# Declarative definitions and operator publication

M23 implementation is in progress. The shared compiler, signed upload owner and
native restart proof are implemented. The optional embedded SQL/Form/Canvas editor passes its native browser, signed
publication and restart proof. Interface-driven shell generation, migration and
generated application qualification remain separate work.

Board embeds `board.sql` as its explicit built-in definition. `GET
/api/v1/interface` returns a compiler-validated built-in artifact or a complete
published definition. Static renderer artifacts remain part of the executable;
SQL cannot load code. A supplied `interface` scope selects a durable application
owner. Board's inspection principal then also needs an explicit read grant for
that resource. Each acquisition uses current public reads, verifies the immutable
body and rechecks the head. Before the first publication, the response explicitly
identifies the built-in artifact. Denial, corruption or an unavailable authority
cannot fall back to a cached definition.

The optional `application` configuration enables `POST /api/v1/application`:

```json
{
  "application": {
    "scope": {
      "realm": 49,
      "application": 9,
      "pid": 17,
      "resource": 19,
      "namespace": "23"
    },
    "operators": [65537, null, null, null, null, null, null, null,
                  null, null, null, null, null, null, null, null]
  }
}
```

These are example public identities, not provisioning instructions. Provision the
actual Station application owner with its immutable configuration and independent
bootstrap administrator first, then grant operators native send/read rights and
the owner's publication policy. The server refuses reuse of its inspection,
query or reactive principal as an operator. At most sixteen explicitly allowed
operator identities can access this endpoint; this deployment bound is not the
number of durable application revisions or operators supported by Transit.

The endpoint is disabled when `application` is absent. It requires the exact
configured Origin, Host and JSON content type. Its 512 KiB request cap admits JSON
escaping of a complete 64 KiB program; semantic program, member and upload bounds
remain smaller. It shares the listener's finite handler capacity, request deadline
and read throttle. Telemetry records the fixed route, never program or key bytes.

The private deployment boundary admits inspection viewers. Operator writes
additionally require an attributable native signature, current native grants and
current application policy. The trusted host prepares the shared native digest;
the browser signs it with a locally imported PKCS#8 Ed25519 key. The host never
receives that private key. This profile trusts the application origin and scripts;
it does not establish human authentication or defend against a compromised origin.

SQL, Form and Canvas edits return to the same Zig semantic validator. Review
freezes the exact expected base, next revision and publication digest. Publishing
stages bounded parts and activates only after complete owner validation. A native
admission receipt is distinct from application completion. Lost replies retain
the exact signed submission across route changes. Explicit pending export/import
supports browser-reload recovery without retaining the private key. See the
[shared browser recovery guide](../../../packages/ts/transit-application/docs/operator.md).
Bootstrap policy repair remains an independently provisioned native administrator
operation; editing a broken definition cannot grant its own recovery rights.
