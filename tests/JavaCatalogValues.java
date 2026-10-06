package io.transit.sdk.station;

import com.google.gson.*;
import io.transit.client.*;
import static io.transit.sdk.station.Catalog.*;
import static io.transit.client.internal.Values.obj;
import java.math.BigInteger;
import java.nio.file.*;
import java.util.*;
import java.util.concurrent.*;

/** Installed values, decoder failures and actual owned-port cancellation. */
public final class JavaCatalogValues {
    private JavaCatalogValues() {}
    private static void check(boolean value) { if (!value) throw new AssertionError("Catalog ownership assertion failed"); }
    private static <E extends Throwable> E rejects(Class<E> type, Runnable work) {
        try { work.run(); } catch (Throwable e) { if (type.isInstance(e)) return type.cast(e); throw new AssertionError("Wrong failure", e); } throw new AssertionError("Expected failure");
    }
    private static <T> T await(CompletableFuture<T> value) { try { return value.join(); } catch (CompletionException e) { if (e.getCause() instanceof RuntimeException r) throw r; throw e; } }
    private static final BigInteger MAX = BigInteger.ONE.shiftLeft(64).subtract(BigInteger.ONE);
    private static final Scope SCOPE = new Scope(new ResourceRef(46, 7), MAX);
    private static final Connection CONNECTION = new Connection(new ProcessRef(46, 3), SCOPE);
    private static BigInteger n(long value) { return BigInteger.valueOf(value); }
    private static Catalog.Client open(Path root, String mode) throws Exception {
        Files.deleteIfExists(root.resolve("entered")); Files.deleteIfExists(root.resolve("release")); Files.writeString(root.resolve("mode.json"), mode);
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
    private static JsonObject metadata() { return obj("scope", SCOPE.wire(), "object", MAX.toString(), "revision", MAX.toString(), "name", "items", "schema_fingerprint", "ab".repeat(32), "principal", 17, "operation", MAX.toString(), "admitted_input", 9); }
    private static Schema schema() { return new Schema(MAX, n(1), n(2), List.of(new Column(n(1), "id", Logical.Scalar.INT128))); }
    private static JsonObject entry() { return obj("metadata", metadata(), "head", obj("revision", "1", "rows", "0", "pending", "0")); }
    private static JsonObject definition() { JsonObject out = entry(); out.add("schema", schema().wire()); return out; }
    private static JsonObject page() {
        JsonArray entries = new JsonArray(); entries.add(entry()); while (entries.size() < 8) entries.add(JsonNull.INSTANCE);
        return obj("resource_revision", 9, "entries", entries, "next", new Cursor(DEFINITION, SCOPE, 9, MAX).wire());
    }
    private static void metadataValues() {
        JsonObject wire = definition(); Definition original = CatalogValues.decode(() -> CatalogValues.resolved(wire, SCOPE, "items")).orElseThrow();
        check(original.metadata().object().equals(MAX) && original.metadata().revision().equals(MAX) && original.schema().equals(schema()));
        wire.getAsJsonObject("metadata").addProperty("name", "changed"); wire.getAsJsonObject("schema").getAsJsonArray("columns").get(0).getAsJsonObject().addProperty("name", "changed");
        check(original.metadata().name().equals("items") && original.schema().columns().getFirst().name().equals("id"));
        check(CatalogValues.resolved(JsonNull.INSTANCE, SCOPE, "missing").isEmpty());
        JsonObject historical = obj("metadata", metadata(), "schema", schema().wire());
        check(CatalogValues.historical(historical, SCOPE, MAX, MAX).orElseThrow().schema().equals(original.schema()));
        for (Runnable decode : List.<Runnable>of(
            () -> CatalogValues.resolved(definition(), SCOPE, "wrong"),
            () -> CatalogValues.historical(historical, SCOPE, n(1), MAX),
            () -> CatalogValues.historical(historical, SCOPE, MAX, n(1)),
            () -> CatalogValues.resolved(definition(), new Scope(SCOPE.resource(), n(1)), "items"))) rejects(TransitException.class, decode);
        JsonObject source = page(); Page page = CatalogValues.page(source, SCOPE, Optional.empty()); source.getAsJsonArray("entries").set(0, JsonNull.INSTANCE);
        check(page.entries().size() == 1 && page.entries().getFirst().metadata().equals(original.metadata())); rejects(UnsupportedOperationException.class, () -> page.entries().clear());
        List<Entry> input = new ArrayList<>(page.entries()); Page copy = new Page(9, input, page.next()); input.clear(); check(copy.equals(page));
        for (int index = 0; index < 11; index++) {
            JsonObject bad = page(); JsonArray entries = bad.getAsJsonArray("entries"); JsonObject next = bad.getAsJsonObject("next"), first = entries.get(0).getAsJsonObject().getAsJsonObject("metadata");
            switch (index) {
                case 0 -> entries.remove(7);
                case 1 -> { entries.set(1, entries.get(0)); entries.set(0, JsonNull.INSTANCE); }
                case 2 -> entries.set(1, entries.get(0));
                case 3 -> first.getAsJsonObject("scope").addProperty("catalog", "1");
                case 4 -> next.remove("definition");
                case 5 -> next.addProperty("definition", "0".repeat(64));
                case 6 -> next.addProperty("after_object", "1");
                case 7 -> next.addProperty("resource_revision", 10);
                case 8 -> first.addProperty("object", MAX);
                case 9 -> first.addProperty("revision", "01");
                case 10 -> bad.addProperty("extra", true);
                default -> throw new AssertionError();
            }
            check(rejects(TransitException.class, () -> CatalogValues.decode(() -> CatalogValues.page(bad, SCOPE, Optional.empty()))).kind() == TransitException.Kind.INCOMPATIBLE_NATIVE);
        }
        rejects(TransitException.class, () -> CatalogValues.page(page(), SCOPE, page.next()));
        JsonObject empty = page(); empty.getAsJsonArray("entries").set(0, JsonNull.INSTANCE); empty.add("next", JsonNull.INSTANCE);
        check(CatalogValues.page(empty, SCOPE, page.next()).entries().isEmpty());
        empty.add("next", new Cursor(DEFINITION, SCOPE, 9, n(9)).wire()); check(CatalogValues.page(empty, SCOPE, Optional.of(new Cursor(DEFINITION, SCOPE, 9, n(8)))).next().orElseThrow().afterObject().equals(n(9)));
    }
    public static void main(String[] args) throws Exception {
        Logical.Cell largeCell = new Logical.Present(new Logical.Binary(new Logical.BinaryData(new byte[1024 * 1024])));
        Logical.Cell laterInvalid = new Logical.Present(new Logical.Sequence(Logical.SequenceKind.LIST, List.of(largeCell, largeCell)));
        Schema oversizedSchema = new Schema(n(1), n(1), n(3), List.of(
            new Column(n(1), "data", Logical.Scalar.BINARY, true, Optional.of(largeCell), Optional.empty()),
            new Column(n(2), "later", Logical.Scalar.BINARY, true, Optional.of(laterInvalid), Optional.empty())));
        check(rejects(IllegalArgumentException.class, oversizedSchema::wire).getMessage().equals("Table wire budget exceeded"));
        List<List<Assignment>> oversizedRows = new ArrayList<>(Collections.nCopies(9, List.of(new Assignment(n(1), largeCell))));
        oversizedRows.add(List.of(new Assignment(n(1), laterInvalid)));
        check(rejects(IllegalArgumentException.class, () -> new Insert(oversizedRows).wire()).getMessage().equals("Table wire budget exceeded"));
        JavaLogicalValues.run(); metadataValues();
        Path root = Path.of(args[0]); Files.writeString(root.resolve("seed"), "11".repeat(32));
        rejects(IllegalArgumentException.class, () -> new Scope(SCOPE.resource(), MAX.add(n(1)))); rejects(IllegalArgumentException.class, () -> new Connection(new ProcessRef(47, 3), SCOPE));
        rejects(IllegalArgumentException.class, () -> new SavedIntent("0".repeat(64), new byte[]{1})); rejects(IllegalArgumentException.class, () -> new Prepared(new Bytes(new byte[8193])));
        rejects(IllegalArgumentException.class, () -> new Prepared(new Bytes(new byte[]{(byte)255})));
        byte[] original = {1,2}; Prepared prepared = new Prepared(new Bytes(original)); SavedIntent saved = new SavedIntent(DEFINITION, original); original[0] = 0; prepared.bytes().copy()[0] = 0; saved.bytes()[0] = 0; check(prepared.bytes().copy()[0] == 1 && saved.bytes()[0] == 1);
        for (String text : List.of("null", "{}", "{\"receipt\":{\"position\":0}}", "{\"receipt\":{\"position\":\"1\"}}", "{\"receipt\":{\"position\":1.5}}", "{\"receipt\":{\"position\":1,\"extra\":true}}", "{\"receipt\":{\"position\":1},\"extra\":true}")) {
            check(rejects(TransitException.class, () -> Catalog.admission(new Gson().fromJson(text, JsonElement.class))).kind() == TransitException.Kind.UNKNOWN_OUTCOME);
        }
        check(rejects(TransitException.class, () -> Catalog.submission(() -> { throw new OutOfMemoryError("injected result allocation"); })).kind() == TransitException.Kind.UNKNOWN_OUTCOME);
        TransitException denial = new TransitException(TransitException.Kind.ACCESS_DENIED, 4, "CatalogDenied", "injected"); check(rejects(TransitException.class, () -> Catalog.submission(() -> { throw denial; })) == denial);
        JsonObject diagnostic = new Gson().fromJson(Files.readString(Path.of("../diagnostic.json")), JsonObject.class);
        JsonObject result = obj("kind", "insert", "operation", MAX.toString(), "object", MAX.toString(), "actual_object", MAX.toString(), "phase", "applied", "terminal", true, "counts", obj("matched", "1", "changed", "1"), "admitted_input", 7, "completed_input", 8, "diagnostic", diagnostic);
        Outcome retained = CatalogValues.outcome(result).orElseThrow(); diagnostic.addProperty("message", ""); retained.diagnostic().addProperty("message", ""); check(!retained.diagnostic().get("message").getAsString().isEmpty());
        for (String field : List.of("counts", "terminal", "phase", "object", "diagnostic")) {
            JsonObject bad = result.deepCopy(); bad.add(field, JsonNull.INSTANCE);
            rejects(TransitException.class, () -> CatalogValues.decode(() -> CatalogValues.outcome(bad)));
        }
        // Both large request and response use the actual owned catalog port.
        Reference reference = new Reference(DEFINITION, new Bytes(new byte[32])); Identity identity = new Identity(n(10), n(100));
        JsonObject summary = obj("reference", reference.wire(), "scope", SCOPE.wire(), "owner", 3, "principal", 17, "operation", "10", "namespace", "100", "object", "1", "kind", "insert");
        JsonObject compiled = obj("intent", summary, "saved", obj("definition", DEFINITION, "bytes", "ab".repeat(300000)));
        Mutate operation = new Mutate(new Basis(n(1), n(1), new Bytes(new byte[32])), new Insert(List.of(List.of(new Assignment(n(1), new Logical.Present(new Logical.Binary(new Logical.BinaryData(new byte[300000]))))))));
        for (String field : List.of("owner", "principal", "operation", "namespace", "object", "kind")) {
            JsonObject bad = compiled.deepCopy(); if (field.equals("owner") || field.equals("principal")) bad.getAsJsonObject("intent").addProperty(field, 18); else bad.getAsJsonObject("intent").addProperty(field, field.equals("kind") ? "update" : "11");
            rejects(TransitException.class, () -> CatalogValues.compiled(bad, CONNECTION, 17, identity, Kind.INSERT, n(1)));
        }
        try (Catalog.Client large = open(root, obj("status", 0, "value", obj("compiled", compiled)).toString())) {
            Compiled actual = await(large.prepare("items", identity, operation)); check(actual.saved().bytes().length == 300000 && actual.intent().identity().equals(identity));
        }
        joined(root);
        for(String mode:List.of("\"loss\"","{\"status\":0,\"value\":{\"receipt\":{\"position\":\"1\"}}}","{\"status\":0,\"value\":{\"receipt\":{\"position\":7},\"extra\":true}}")) {
            try(var client=open(root,mode)){check(rejects(TransitException.class,() -> await(client.submit(prepared))).kind()==TransitException.Kind.UNKNOWN_OUTCOME);check(prepared.bytes().copy()[0]==1);}
            joined(root);
        }
        try(var client=open(root,"{\"status\":4,\"value\":{\"err\":\"CatalogDenied\"}}")) {
            TransitException e=rejects(TransitException.class,() -> await(client.submit(prepared)));check(e.kind()==TransitException.Kind.ACCESS_DENIED && e.status()==4 && e.code().equals("CatalogDenied"));
        }
        joined(root);
        try(var client=open(root,"{\"status\":0,\"value\":{\"receipt\":{\"position\":7}}}")){check(await(client.submit(prepared)).position()==7);}
        joined(root);
        Catalog.Client client=open(root,"\"block\"");CompletableFuture<?> closing=null;
        try {
            var pending=client.submit(prepared);waitFor(root.resolve("entered"));check(pending.cancel(true));
            check(rejects(TransitException.class,() -> await(client.capabilities())).kind()==TransitException.Kind.BUSY);
            CountDownLatch started=new CountDownLatch(1);closing=CompletableFuture.runAsync(() -> {started.countDown();client.close();});check(started.await(5,TimeUnit.SECONDS));
            try{closing.get(100,TimeUnit.MILLISECONDS);throw new AssertionError("Close abandoned active native work");}catch(TimeoutException expected){}
            Files.writeString(root.resolve("release"),"1");closing.get(5,TimeUnit.SECONDS);check(pending.isCancelled());check(prepared.bytes().copy()[0]==1);
        } finally {Files.writeString(root.resolve("release"),"1");client.close();if(closing!=null)closing.get(5,TimeUnit.SECONDS);}
        joined(root);check(rejects(TransitException.class,() -> await(client.capabilities())).kind()==TransitException.Kind.CLOSED);
        System.out.println("Java general Tables: owned logical families/budgets, metadata, large frames, uncertain receipts and joined cancellation passed.");
    }
}
