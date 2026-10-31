# Declarative browser example

This example publishes `catalog_items`, a fictional content directory. Its table,
columns and filter live in the migration and declaration; the browser runtime
has no application schema. It uses the migration workflow introduced in PR #285.

Build from the checkout with the pinned tools:

```sh
nix develop --command zig build transit transit-admin -Doptimize=ReleaseSafe
export PATH="$PWD/zig-out/bin:$PATH"
mkdir -m 700 /var/tmp/transit-browser-example
cd /var/tmp/transit-browser-example
transit server --no-ui
```

In another terminal, with the same PATH and working directory, use the absolute
checkout path in place of `/checkout/transit`:

```sh
transit migrate plan --dir /checkout/transit/examples/declarative-browser/migrations --out migration.json --format json
cat migration.json
transit migrate apply --plan migration.json --format json
python3 /checkout/transit/examples/declarative-browser/configure.py --node http://127.0.0.1:19104
cp browser-private/placement.json transit.yaml
```

The copy above assumes a fresh example with no existing `transit.yaml`; otherwise
merge its `browser` field. Stop and restart the first terminal's server. Its ready
record now includes successful browser key loading, catalog reconciliation and
listener binding. The listener runs inside the native node; there is no browser
process. The generated example uses the local SQL reader credential. Production
publications should select a dedicated native reader with only the required
source privileges; a social login never inherits this credential.

```sh
curl -H 'Origin: http://127.0.0.1:8090' http://127.0.0.1:8090/published/catalog/snapshot
transit console --no-rc -c "UPDATE catalog_items SET title = 'Changed' WHERE id = 9007199254740993;"
```

The snapshot contains only the public row and represents its ID as the string
`"9007199254740993"`. A same-origin browser opens
`new WebSocket('ws://127.0.0.1:8090/published/catalog/watch', 'transit.published.v1')`.
It receives an initial snapshot and another after a source watermark changes.
The static application must proxy these paths under its own exact origin; the
browser listener does not host an HTML application.

For sign-in, prepare provider declarations following [the browser contract](../../contracts/BROWSER_V1.md#provider-registration),
then pass `--provider google.json --secret google-client=/private/google-client-secret`
(and equivalent arguments for GitHub/Facebook) to `configure.py` on the first run.
The helper applies only public typed `transit-admin browser` operations and saves
each original request and response under `browser-private/requests`. It does not
retry failed or uncertain changes. An already configured deployment uses explicit
inspection and conditional updates from the contract instead of rerunning setup.

Provider console consent, callback registration and app review require real
operator-owned registrations. For a credential-free reproducible proof with
independent provider peers, signed OIDC responses, HTTP and WS consumers, run:

```sh
nix develop --command just test::declarative-browser
```

That proof owns a disposable real installation, applies this migration, exercises
all three provider modes and retains private state on failure. It is separate
from live consent testing. Preserve the `.transit` data directory, cookie seed,
mounted secrets and matching artifact definition across task replacement. Earlier
definitions reject at the compatibility boundary; see [versioning](../../docs/handbook/reference/versioning.md).
