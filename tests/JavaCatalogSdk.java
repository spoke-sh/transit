import com.google.gson.*;
import io.transit.client.*;
import io.transit.sdk.station.Catalog;
import io.transit.sdk.station.Logical;
import static io.transit.sdk.station.Catalog.*;
import java.math.BigInteger;
import java.nio.ByteBuffer;
import java.nio.channels.FileChannel;
import java.nio.charset.StandardCharsets;
import java.nio.file.*;
import java.nio.file.attribute.PosixFilePermissions;
import java.util.*;
import java.util.concurrent.*;

/** Installed Java general Table lifecycle and immutable recovery after name reuse. */
public final class JavaCatalogSdk {
    private JavaCatalogSdk() {}
    private static BigInteger n(long value) { return BigInteger.valueOf(value); }
    private static void check(boolean value) { if (!value) throw new AssertionError("Installed Table assertion"); }
    private static <T> T await(CompletableFuture<T> value) {
        try { return value.join(); } catch (CompletionException e) { if (e.getCause() instanceof RuntimeException r) throw r; throw e; }
    }
    private static Catalog.Client connect(JsonObject config) {
        JsonObject c = config.getAsJsonObject("connection"), s = c.getAsJsonObject("scope"); long realm = s.get("realm").getAsLong();
        Connection connection = new Connection(new ProcessRef(realm, c.get("owner").getAsLong()), new Scope(new ResourceRef(realm, s.get("resource").getAsLong()), new BigInteger(s.get("catalog").getAsString())));
        return Catalog.Client.open(new ClientConfig(java.net.URI.create(config.get("url").getAsString()), ClientConfig.Profile.NATIVE_V1, 10000, null), new Credential(realm, c.get("principal").getAsLong(), Path.of(config.get("seed_file").getAsString())), connection);
    }
    private static void persist(Path path, byte[] bytes) throws java.io.IOException {
        try (FileChannel file = FileChannel.open(path, Set.of(StandardOpenOption.CREATE, StandardOpenOption.TRUNCATE_EXISTING, StandardOpenOption.WRITE), PosixFilePermissions.asFileAttribute(PosixFilePermissions.fromString("rw-------")))) {
            ByteBuffer data = ByteBuffer.wrap(bytes); while (data.hasRemaining()) file.write(data); file.force(true);
        }
    }
    private static Outcome finish(Catalog.Client client, Compiled compiled, Path root) throws java.io.IOException {
        JsonObject saved = new JsonObject(); saved.addProperty("definition", compiled.saved().definition()); saved.addProperty("bytes", HexFormat.of().formatHex(compiled.saved().bytes()));
        persist(root.resolve("intent.json"), saved.toString().getBytes(StandardCharsets.UTF_8));
        Reference reference = compiled.intent().reference(); long deadline = System.nanoTime() + TimeUnit.SECONDS.toNanos(120);
        for (;;) {
            check(System.nanoTime() < deadline); Next step = await(client.next(reference));
            if (step.kind() == NextKind.TERMINAL) return step.outcome().orElseThrow();
            if (step.kind() == NextKind.RUNNING) continue;
            check(step.kind() == NextKind.SEND); Prepared prepared = step.prepared().orElseThrow();
            persist(root.resolve("step.json"), prepared.bytes().copy()); long position = await(client.submit(prepared)).position();
            persist(root.resolve("receipt.json"), Long.toString(position).getBytes(StandardCharsets.UTF_8));
            for (;;) {
                check(System.nanoTime() < deadline); Progress progress = await(client.progress(reference, prepared, position, true));
                if (progress.observation() == Observation.PENDING) continue;
                check(progress.disposition().isEmpty());
                if (progress.outcome().isPresent() && progress.outcome().get().terminal()) return progress.outcome().get();
                break;
            }
        }
    }
    private static Logical.Cell atom(Logical.Atom value) { return new Logical.Present(value); }
    private static Assignment assignment(long column, Logical.Cell value) { return new Assignment(n(column), value); }
    private static JsonObject scenario(Catalog.Client client, JsonObject config, Path root, int index) throws java.io.IOException {
        long base = 1100 + index * 100L, object = 12001 + index * 10L; String name = "sdk_people_" + index;
        java.util.function.IntFunction<Identity> id = offset -> new Identity(n(base + offset), n(base + offset + 100000));
        Description description = await(client.describe()); check(description.configuration().scope().equals(client.connection().scope())); check(description.policy().principal() == config.getAsJsonObject("connection").get("principal").getAsLong());
        Compiled create = await(client.compileSql("CREATE TABLE " + name + " (id INTEGER PRIMARY KEY, payload STRUCT(data BINARY, label UTF8), amount DECIMAL(38,2))", id.apply(0), Optional.of(n(object))));
        check(finish(client, create, root).phase() == Phase.APPLIED);
        Definition original = await(client.lookup(name)).orElseThrow(); check(original.schema().columns().size() == 3 && original.schema().columns().get(1).type() instanceof Logical.Structure);
        Logical.Cell payload = new Logical.Present(new Logical.Sequence(Logical.SequenceKind.STRUCTURE, List.of(atom(new Logical.Binary(new Logical.BinaryData(new byte[]{0, (byte)128, (byte)255}))), atom(new Logical.Utf8("東京")))));
        Logical.Cell amount = atom(new Logical.DecimalValue(new BigInteger("123456789012345678901234567890")));
        Compiled insert = await(client.prepare(name, id.apply(1), new Mutate(original.metadata().basis(), new Insert(List.of(List.of(assignment(3, amount), assignment(1, atom(new Logical.Signed(n(1)))), assignment(2, payload)))))));
        Outcome applied = finish(client, insert, root); check(applied.counts().orElseThrow().equals(new Counts(n(1), n(1))));
        Optional<List<Predicate>> predicate = Optional.of(List.of(new Comparison(n(1), CompareOperator.EQ, new Logical.Signed(n(1)))));
        Compiled update = await(client.prepare(name, id.apply(2), new Mutate(original.metadata().basis(), new Update(List.of(assignment(3, amount)), predicate))));
        check(finish(client, update, root).counts().orElseThrow().equals(new Counts(n(1), n(0))));
        Compiled alter = await(client.prepare(name, id.apply(3), new Alter(original.metadata().basis(), new AddColumn("enabled", Logical.Scalar.BOOLEAN, false, Optional.of(atom(new Logical.BooleanValue(true))), Optional.empty()))));
        check(finish(client, alter, root).phase() == Phase.APPLIED);
        try { await(client.prepare(name, id.apply(4), new Drop(original.metadata().basis()))); throw new AssertionError("Stale basis retargeted work"); } catch (TransitException expected) { }
        Definition current = await(client.lookup(name)).orElseThrow();
        Compiled delete = await(client.prepare(name, id.apply(5), new Mutate(current.metadata().basis(), new Delete(predicate))));
        check(finish(client, delete, root).counts().orElseThrow().equals(new Counts(n(1), n(1))));
        check(finish(client, await(client.prepare(name, id.apply(6), new Drop(current.metadata().basis()))), root).phase() == Phase.APPLIED);
        check(finish(client, await(client.compileSql("CREATE TABLE " + name + " (replacement TEXT)", id.apply(7), Optional.of(n(object + 1)))), root).phase() == Phase.APPLIED);
        client.close();
        try (Catalog.Client replacement = connect(config)) {
            Intent loaded = await(replacement.load(new SavedIntent(insert.saved().definition(), insert.saved().bytes()))); check(loaded.object().equals(n(object)));
            check(await(replacement.status(loaded.reference())).outcome().orElseThrow().equals(applied));
            check(await(replacement.lookup(name)).orElseThrow().metadata().object().equals(n(object + 1)));
            HistoricalDefinition historical = await(replacement.definition(n(object), original.metadata().revision())).orElseThrow();
            check(historical.metadata().equals(original.metadata()) && historical.schema().equals(original.schema()));
            check(await(replacement.definition(n(object), n(999))).isEmpty()); check(!await(replacement.list()).entries().isEmpty());
        }
        JsonObject result = new JsonObject(); result.addProperty("profile", "installed-java-general-table"); result.addProperty("original_object", Long.toString(object)); result.addProperty("replacement_object", Long.toString(object + 1));
        JsonObject counts = new JsonObject(); counts.addProperty("matched", "1"); counts.addProperty("changed", "1"); result.add("counts", counts); return result;
    }
    public static void main(String[] args) throws Exception {
        Path path = Path.of(args[0]); JsonObject config = new Gson().fromJson(Files.readString(path), JsonObject.class);
        try (Catalog.Client client = connect(config)) {
            System.out.println("{\"ready\":true}"); var reader = new java.io.BufferedReader(new java.io.InputStreamReader(System.in, StandardCharsets.UTF_8));
            for (String line; (line = reader.readLine()) != null;) {
                JsonObject action = new Gson().fromJson(line, JsonObject.class); if (action.has("close")) break;
                JsonObject result = new JsonObject(); result.addProperty("status", 0); result.add("value", scenario(client, config, path.getParent(), action.getAsJsonObject("scenario").get("index").getAsInt())); System.out.println(result);
            }
        }
        System.out.println("{\"closed\":true}");
    }
}
