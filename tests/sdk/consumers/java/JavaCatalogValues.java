package io.transit.sdk.station;

import com.google.gson.*;
import io.transit.client.*;
import static io.transit.sdk.station.Catalog.*;
import static io.transit.client.internal.Values.obj;
import java.math.BigInteger;
import java.nio.file.*;
import java.util.*;
import java.util.concurrent.*;

/** Installed boundary ownership and port failures; does not establish authority. */
public final class JavaCatalogValues {
    private JavaCatalogValues() {}
    private static void check(boolean value) { if (!value) throw new AssertionError("Catalog ownership assertion failed"); }
    private static <E extends Throwable> E rejects(Class<E> type, Runnable work) {
        try { work.run(); } catch (Throwable e) { if (type.isInstance(e)) return type.cast(e); throw new AssertionError("Wrong failure", e); } throw new AssertionError("Expected failure");
    }
    private static <T> T await(CompletableFuture<T> value) { try { return value.join(); } catch (CompletionException e) { if (e.getCause() instanceof RuntimeException r) throw r; throw e; } }
    private static final BigInteger MAX = BigInteger.ONE.shiftLeft(64).subtract(BigInteger.ONE);
    private static final Scope SCOPE = new Scope(new ResourceRef(46, 7), MAX);
    private static final Connection CONNECTION = new Connection(SCOPE, 3);
    private static BigInteger n(long value) { return BigInteger.valueOf(value); }
    private static Catalog.Client open(Path root, JsonElement mode) throws Exception {
        Files.deleteIfExists(root.resolve("entered")); Files.deleteIfExists(root.resolve("release")); Files.writeString(root.resolve("mode.json"), mode.toString());
        return Catalog.Client.open(new ClientConfig(java.net.URI.create("http://127.0.0.1:9"), ClientConfig.Profile.NATIVE_V1, 1000, root.resolve("host")), new Credential(46, 17, root.resolve("seed")), CONNECTION);
    }
    private static void waitFor(Path file) throws Exception {
        long deadline = System.nanoTime() + TimeUnit.SECONDS.toNanos(5);
        while (!Files.exists(file)) { if (System.nanoTime() >= deadline) throw new AssertionError("Host did not enter submission"); Thread.sleep(10); }
    }
    private static void joined(Path root) throws Exception {
        long pid = Long.parseLong(Files.readString(root.resolve("host-pid"))); check(ProcessHandle.of(pid).map(p -> !p.isAlive()).orElse(true));
        check(Thread.getAllStackTraces().keySet().stream().noneMatch(t -> t.isAlive() && (t.getName().equals("transit-owned-port") || t.getName().equals("transit-completions"))));
    }
    private static JsonObject objectIdentity() { return obj("scope", SCOPE.wire(), "branch", "1", "object", MAX.toString()); }
    private static JsonObject interpretation() { return obj("object", objectIdentity(), "revision", "1", "digest", "ab".repeat(32)); }
    private static JsonObject stored() { return obj("interpretation", interpretation(), "content", obj("bytes", "300", "sha256", "ab".repeat(32)), "schema_fingerprint", "cd".repeat(32), "retired", false); }
    private static JsonObject basis() { return obj("definition", DEFINITION, "connection", CONNECTION.wire(17), "namespace", 1, "name", "items", "interpretation", stored()); }
    private static JsonObject position() { return obj("partition", MAX.toString(), "next_lsn", MAX.toString()); }
    private static JsonObject binding() { return obj("definition", DEFINITION, "identity", obj("scope", SCOPE.wire(), "principal", 17, "operation", "10"), "target", objectIdentity(), "action", "insert", "expected_definition", interpretation(), "expected_data", null, "intent", "aa".repeat(32), "prerequisite", null); }
    private static JsonObject saved() { return obj("table", obj("definition", DEFINITION, "namespace", 1, "bytes", "aabb")); }
    private static JsonObject reference() { return obj("table", obj("definition", DEFINITION, "connection", CONNECTION.wire(17), "namespace", 1, "binding", binding(), "content", obj("bytes", "200", "sha256", "22".repeat(32)))); }
    private static JsonObject summary() { return obj("id", obj("definition", DEFINITION, "digest", "11".repeat(32)), "namespace", 1, "binding", obj("table", binding())); }
    private static JsonObject observation() { return obj("rows", obj("committed", obj("binding", binding(), "resulting", stored(), "transaction", JsonNull.INSTANCE, "outcome", obj("position", position(), "matched", "9", "affected", "9", "live_rows", "9")))); }
    private static Schema schema() { return new Schema(MAX, n(1), n(2), List.of(new Column(n(1), "id", Logical.Scalar.INT128))); }
    private static JsonObject page() {
        JsonArray entries = new JsonArray(); entries.add(obj("interpretation", interpretation(), "namespace", 1, "name", "items", "position", position(), "changed_lsn", "3")); while (entries.size() < 8) entries.add(JsonNull.INSTANCE);
        return obj("position", position(), "entries", entries, "next", obj("definition", DEFINITION, "connection", CONNECTION.wire(17), "selection", obj("tables", 1), "position", position(), "after", MAX.toString()), "consistency", "independent");
    }
    private static void values() {
        JavaLogicalValues.run();
        Basis basis = Basis.restore(basis().toString()); check(basis.object().equals(MAX) && basis.connection().equals(CONNECTION));
        rejects(IllegalArgumentException.class, () -> Basis.restore(basis.save().substring(0, basis.save().length()-1) + ",\"name\":\"other\"}"));
        check(!basis.toString().contains("items"));
        for (boolean missing : List.of(true, false)) {
            JsonObject value = reference(); if (missing) value.getAsJsonObject("table").remove("definition"); else value.getAsJsonObject("table").addProperty("definition", "00".repeat(32));
            rejects(RuntimeException.class, () -> Reference.restore(value.toString()));
        }
        JsonObject physical = schema().wire(); JsonObject column = physical.getAsJsonArray("columns").get(0).getAsJsonObject();
        column.add("type", obj("utf8", obj())); column.addProperty("encoding", "ebcdic"); column.addProperty("collation", "ebcdic_cp037");
        check(CatalogValues.schema(physical).columns().getFirst().collation() == Collation.EBCDIC_CP037);
        for (String field : List.of("encoding", "collation")) {
            JsonObject bad = physical.deepCopy(); bad.getAsJsonArray("columns").get(0).getAsJsonObject().remove(field);
            rejects(TransitException.class, () -> CatalogValues.decode(() -> CatalogValues.schema(bad)));
        }
        Logical.Cell large = new Logical.Present(new Logical.Binary(new Logical.BinaryData(new byte[1024*1024])));
        Logical.Cell invalid = new Logical.Present(new Logical.Sequence(Logical.SequenceKind.LIST, List.of(large, large)));
        Schema oversizedSchema = new Schema(n(1), n(1), n(3), List.of(
            new Column(n(1), "data", Logical.Scalar.BINARY, true, Optional.of(large), Optional.empty(), Encoding.PLAIN, Collation.NONE),
            new Column(n(2), "later", Logical.Scalar.BINARY, true, Optional.of(invalid), Optional.empty(), Encoding.PLAIN, Collation.NONE)));
        check(rejects(IllegalArgumentException.class, oversizedSchema::wire).getMessage().equals("Table wire budget exceeded"));
        List<List<Assignment>> oversized = new ArrayList<>(Collections.nCopies(9, List.of(new Assignment(n(1), large)))); oversized.add(List.of(new Assignment(n(1), invalid)));
        check(rejects(IllegalArgumentException.class, () -> new Insert(oversized).wire()).getMessage().equals("Table wire budget exceeded"));
        JsonArray context = new JsonArray(); for (int i=0; i<32; i++) context.add(1);
        AuthorityProfile authority = new AuthorityProfile(10,11,12,13,14,20,1,21);
        JsonObject description = obj("configuration", obj("scope", SCOPE.wire(), "branch", "1", "partition", MAX.toString(), "audience", 3, "authority", authority.wire(), "database_name", "ledger", "initial_schema_name", "public"),
            "subject", obj("principal",17,"login_role",17,"role",17,"credential_epoch",1,"audience",3,"context",context), "policy_revision",2);
        CatalogValues.response(obj("catalog",obj("description",description)));
        check(CatalogValues.description(description,CONNECTION,17).configuration().partition().equals(MAX));
        check(CatalogValues.description(description,CONNECTION,17).configuration().authority().equals(authority));
        for (String field : List.of("stream_domain", "queue_domain")) {
            JsonObject missing = description.deepCopy(); missing.getAsJsonObject("configuration").getAsJsonObject("authority").remove(field);
            rejects(TransitException.class, () -> CatalogValues.response(obj("catalog",obj("description",missing))));
            for (long value : new long[]{0,10,11,12,field.equals("stream_domain") ? 14 : 13,9007199254740992L}) {
                JsonObject bad = description.deepCopy(); bad.getAsJsonObject("configuration").getAsJsonObject("authority").addProperty(field,value);
                rejects(TransitException.class, () -> CatalogValues.decode(() -> CatalogValues.description(bad,CONNECTION,17)));
            }
        }
        for (String field : List.of("principal", "audience", "credential_epoch")) {
            JsonObject bad = description.deepCopy(); bad.getAsJsonObject("subject").addProperty(field, field.equals("credential_epoch") ? 0 : 18);
            rejects(TransitException.class, () -> CatalogValues.decode(() -> CatalogValues.description(bad,CONNECTION,17)));
        }
        JsonObject p = page(); CatalogValues.response(obj("catalog", obj("tables", p)));
        Page<Entry> original = CatalogValues.tables(p, CONNECTION, 17, 1, Optional.empty()); p.getAsJsonArray("entries").set(0, JsonNull.INSTANCE);
        check(original.entries().getFirst().interpretation().object().object().equals(MAX)); rejects(UnsupportedOperationException.class, () -> original.entries().clear());
        for (int i=0; i<9; i++) {
            JsonObject bad = page(); JsonArray entries = bad.getAsJsonArray("entries"); JsonObject next = bad.getAsJsonObject("next"), first = entries.get(0).getAsJsonObject();
            switch (i) {
                case 0 -> entries.remove(7);
                case 1 -> { entries.set(1, entries.get(0)); entries.set(0, JsonNull.INSTANCE); }
                case 2 -> entries.set(1, entries.get(0));
                case 3 -> first.getAsJsonObject("interpretation").getAsJsonObject("object").getAsJsonObject("scope").addProperty("catalog", "1");
                case 4 -> next.remove("definition");
                case 5 -> next.addProperty("after", "1");
                case 6 -> next.getAsJsonObject("position").addProperty("next_lsn", "1");
                case 7 -> first.addProperty("namespace", 2);
                case 8 -> first.getAsJsonObject("interpretation").getAsJsonObject("object").addProperty("object", MAX);
                default -> throw new AssertionError();
            }
            rejects(TransitException.class, () -> CatalogValues.decode(() -> { CatalogValues.response(obj("catalog", obj("tables", bad))); return CatalogValues.tables(bad, CONNECTION, 17, 1, Optional.empty()); }));
        }
        rejects(TransitException.class, () -> CatalogValues.tables(page(), CONNECTION, 17, 1, original.next()));
        Reference reference = Reference.restore(reference().toString());
        check(CatalogValues.observation(observation(), reference).commit().orElseThrow().position().nextLsn().equals(MAX));
        JsonObject bad = observation(); bad.getAsJsonObject("rows").getAsJsonObject("committed").getAsJsonObject("binding").getAsJsonObject("identity").addProperty("operation", "11");
        rejects(TransitException.class, () -> CatalogValues.observation(bad, reference));
        JsonObject acquisitionWire = obj("owner", obj("definition", DEFINITION, "connection", CONNECTION.wire(17), "object", objectIdentity(), "operation", MAX.toString()), "expected", position());
        SnapshotAcquisition acquisition = SnapshotAcquisition.restore(acquisitionWire.toString()); check(acquisition.owner().operation().equals(MAX));
        Snapshot snapshot = Snapshot.restore(obj("owner", acquisition.owner().wire(), "content", obj("bytes", "500", "sha256", "44".repeat(32))).toString());
        JsonObject metadata = obj("snapshot", snapshot.wire(), "interpretation", stored(), "accepted", position(), "changed_lsn", "3", "row_count", "9", "schema", schema().wire(), "authority", obj("database", 31, "schema", 32, "table", 33));
        CatalogValues.response(obj("retention", obj("metadata", metadata)));
        check(CatalogValues.snapshotMetadata(metadata, snapshot).rowCount().equals(n(9)));
        metadata.getAsJsonObject("snapshot").getAsJsonObject("content").addProperty("sha256", "55".repeat(32));
        rejects(TransitException.class, () -> CatalogValues.snapshotMetadata(metadata, snapshot));
    }
    public static void main(String[] args) throws Exception {
        values(); Path root = Path.of(args[0]); Files.writeString(root.resolve("seed"), "11".repeat(32));
        Reference reference = Reference.restore(reference().toString());
        JsonObject compiled = obj("summary", summary(), "saved", obj("table", obj("definition", DEFINITION, "namespace", 1, "bytes", "ab".repeat(300000))));
        Mutate operation = new Mutate(Basis.restore(basis().toString()), new Insert(List.of(List.of(new Assignment(n(1), new Logical.Present(new Logical.Binary(new Logical.BinaryData(new byte[300000]))))))), Ingestion.BULK);
        try (Catalog.Client client = open(root, obj("status", 0, "value", obj("compiled", compiled)))) {
            Compiled actual = await(client.prepare("items", new Identity(n(10)), operation)); check(actual.saved().wire().getAsJsonObject("table").get("bytes").getAsString().length() == 600000);
        }
        joined(root);
        for (JsonElement mode : List.of(new JsonPrimitive("loss"), obj("status", 0, "value", obj("observation", obj())))) {
            try (Catalog.Client client = open(root, mode)) {
                Uncertain error = rejects(Uncertain.class, () -> await(client.execute(reference, 32))); check(error.original().equals(reference) && error.failure().status() == 6);
            }
            joined(root);
        }
        try (Catalog.Client client = open(root, obj("status", 4, "value", obj("err", "CatalogDenied")))) {
            check(rejects(TransitException.class, () -> await(client.execute(reference, 32))).kind() == TransitException.Kind.ACCESS_DENIED);
        }
        joined(root);
        JsonObject reply = obj("status", 0, "value", obj("observation", observation()));
        try (Catalog.Client client = open(root, reply)) { check(await(client.inspect(reference)).commit().orElseThrow().affected().equals(n(9))); }
        joined(root); Files.writeString(root.resolve("reply.json"), reply.toString());
        Catalog.Client client = open(root, new JsonPrimitive("block")); CompletableFuture<?> closing = null;
        try {
            var pending = client.execute(reference, 32); waitFor(root.resolve("entered")); check(pending.cancel(true));
            check(rejects(TransitException.class, () -> await(client.capabilities())).kind() == TransitException.Kind.BUSY);
            CountDownLatch started = new CountDownLatch(1); closing = CompletableFuture.runAsync(() -> { started.countDown(); client.close(); }); check(started.await(5, TimeUnit.SECONDS));
            try { closing.get(100, TimeUnit.MILLISECONDS); throw new AssertionError("Close abandoned native work"); } catch (TimeoutException expected) { }
            Files.writeString(root.resolve("release"), "1"); closing.get(5, TimeUnit.SECONDS); check(pending.isCancelled());
        } finally { Files.writeString(root.resolve("release"), "1"); client.close(); if (closing != null) closing.get(5, TimeUnit.SECONDS); }
        joined(root); check(rejects(TransitException.class, () -> await(client.capabilities())).kind() == TransitException.Kind.CLOSED);
        System.out.println("Java direct catalog: owned nested types, complete wide bindings, pages, retained metadata, large frames, uncertain replies and joined cancellation passed.");
    }
}
