"""Public Python sync/async callers against the direct captured-query fixture."""
import asyncio
import base64
import json
from pathlib import Path


async def exercise(profile, endpoint, phase, native_directory, asynchronous):
    from transit_client import ProcessRef, ResourceRef
    from transit_client.errors import TransitError
    from transit_station import unified as q, logical as l, catalog

    saved = json.loads(profile.read_text())["captured"]
    route = saved["connection"]
    realm = route["realm"]
    connection = q.Connection(ProcessRef(realm, route["source"]), ResourceRef(realm, route["resource"]),
        ProcessRef(realm, route["requester"]), ResourceRef(realm, route["requests"]))
    declared = saved["declaration"]["source"]["table"]
    scope = catalog.Scope(ResourceRef(realm, declared["scope"]["resource"]), int(declared["scope"]["catalog"]))
    assert scope.resource != connection.resource
    interpretation = declared["interpretation"]
    source = q.TableSource(scope, declared["owner"], int(declared["branch"]), declared["namespace"],
        q.TableInterpretation(int(interpretation["revision"]), bytes(interpretation["digest"]),
            int(interpretation["bytes"]), bytes(interpretation["schema"])),
        catalog.Schema(61, 1, 2, (catalog.Column(1, "id", l.ScalarType("int64"), False),), (1,)))
    bundle = q.Bundle(base64.b64decode(saved["bundle"]["base64"], validate=True))
    seed = profile.parent / "python-capture.seed"
    seed.write_text(bytes([29 if phase == "prepare" else 59]).hex() * 32)
    seed.chmod(0o600)
    owner = (q.AsyncClient if asynchronous else q.Client)(endpoint, route["principal"], seed, connection,
        tables=q.Tables(endpoint, scope, int(declared["branch"]), declared["owner"]),
        native_directory=native_directory, timeout_ms=10000)

    async def invoke(method, *args):
        result = getattr(owner, method)(*args)
        return await result if asynchronous else result

    try:
        if phase == "prepare":
            assert await invoke("lookup_table", "missing_capture_input") is None
            definition = await invoke("lookup_table", "captured_input")
            assert definition is not None and definition.source == source
            description = await invoke("describe", definition.source)
            assert description.bundle_bytes == 25613
            compiled = await invoke("compile_sql", source, "captured_input",
                "SELECT COUNT(*) AS n FROM captured_input", q.Budgets(64, 64, 1048576))
            capture = saved["capture"]
            assert definition.partition == int(capture["expected"]["partition"])
            assert definition.next_lsn == int(capture["expected"]["next_lsn"])
            sealed = await invoke("authorize_bundle", compiled,
                definition.capture(capture["executor"], int(capture["operation"])))
            assert sealed == bundle, "Python changed the frozen Zig capture binding"
        else:
            assert await invoke("lookup_table", "captured_input") is None
            current = await invoke("lookup_table", "captured_renamed")
            assert current is not None and current.source.interpretation.revision == 2
            assert current.source.schema == source.schema
            page = await invoke("page", 1)
            assert page.next is None and page.rows == 1
            assert page.manifest.source == connection.source
            assert page.manifest.resource == scope.resource
            assert isinstance(page.manifest.cut, q.TableCut)
            assert len(page.manifest.cut.commitment) == 32
            assert page.manifest.scanned == 19 and page.manifest.pages == 3
            assert page.decode(native_directory=native_directory) == ((l.Present(l.Atom("unsigned", 19)),),)
            cleanup = await invoke("prepare_cleanup", 1, bundle)
            assert isinstance(cleanup, q.Prepared) and cleanup.data
        try:
            await invoke("authorize_bundle", bundle)
        except TransitError:
            pass
        else:
            raise AssertionError("An accepted Table bundle was resealed")
    finally:
        await invoke("close")


def run(profile, endpoint, phase, native_directory=None):
    for asynchronous in (False, True):
        asyncio.run(exercise(Path(profile), endpoint, phase, Path(native_directory) if native_directory is not None else None, asynchronous))
    print(f"Python direct capture {phase}: sync/async public API passed", flush=True)


if __name__ == "__main__":
    import sys
    run(Path(sys.argv[2]), sys.argv[1], sys.argv[3])
