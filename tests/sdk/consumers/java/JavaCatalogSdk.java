import com.google.gson.*;
import io.transit.client.*;
import io.transit.sdk.station.Catalog;
import io.transit.sdk.station.Logical;
import static io.transit.sdk.station.Catalog.*;
import static io.transit.client.internal.Values.obj;
import java.math.BigInteger;
import java.nio.ByteBuffer;
import java.nio.channels.FileChannel;
import java.nio.charset.StandardCharsets;
import java.nio.file.*;
import java.nio.file.attribute.PosixFilePermissions;
import java.util.*;
import java.util.concurrent.*;

/** Installed direct Table lifecycle; exact retained metadata, not SQL row reads. */
public final class JavaCatalogSdk {
    private JavaCatalogSdk() {}
    private static BigInteger n(long value) { return BigInteger.valueOf(value); }
    private static void check(boolean value) { if (!value) throw new AssertionError("Installed direct catalog assertion"); }
    private static <T> T await(CompletableFuture<T> value) { try { return value.join(); } catch (CompletionException e) { if (e.getCause() instanceof RuntimeException r) throw r; throw e; } }
    private static Catalog.Client connect(JsonObject config) {
        JsonObject c = config.getAsJsonObject("connection"), s = c.getAsJsonObject("scope"); long realm = s.get("realm").getAsLong();
        Connection connection = new Connection(new Scope(new ResourceRef(realm, s.get("resource").getAsLong()), new BigInteger(s.get("catalog").getAsString())), c.get("audience").getAsLong(), new BigInteger(c.get("branch").getAsString()), c.get("role").isJsonNull() ? Optional.empty() : Optional.of(c.get("role").getAsLong()));
        return Catalog.Client.open(new ClientConfig(java.net.URI.create(config.get("url").getAsString()), ClientConfig.Profile.NATIVE_V1, 10000, null), new Credential(realm, c.get("principal").getAsLong(), Path.of(config.get("seed_file").getAsString())), connection, config.get("service_url").getAsString());
    }
    private static void persist(Path path, String value) throws java.io.IOException {
        try (FileChannel file = FileChannel.open(path, Set.of(StandardOpenOption.CREATE, StandardOpenOption.TRUNCATE_EXISTING, StandardOpenOption.WRITE), PosixFilePermissions.asFileAttribute(PosixFilePermissions.fromString("rw-------")))) {
            ByteBuffer data = ByteBuffer.wrap(value.getBytes(StandardCharsets.UTF_8)); while (data.hasRemaining()) file.write(data); file.force(true);
        }
    }
    private static Observation complete(Catalog.Client client, Compiled work, Path directory) throws java.io.IOException {
        persist(directory.resolve("work.json"), work.saved().save()); Reference original = await(client.stage(work.intent()));
        persist(directory.resolve("work-reference.json"), original.save()); Observation observed = await(client.admit(original));
        for (int i=0; i<16 && observed.state() == OperationState.ADMITTED; i++) observed = await(client.execute(original, 32));
        check(observed.state() == OperationState.COMMITTED); return observed;
    }
    private static Compiled compile(Catalog.Client client, String sql, long operation) { return await(client.compileSql(sql, new Identity(n(operation)))); }
    private static void uncertain(Recovery original, Runnable action) {
        try { action.run(); } catch (Uncertain error) {
            check(error.original().save().equals(original.save()) && error.failure().status() == 6 && !error.failure().diagnosticInvalid() && error.failure().diagnostic().get("outcome").getAsString().equals("unknown")); return;
        }
        throw new AssertionError("Expected original operation uncertainty");
    }
    private static Snapshot snapshot(Path directory) throws java.io.IOException { return Snapshot.restore(Files.readString(directory.resolve("snapshot.json"))); }
    public static void main(String[] args) throws Exception {
        Path configPath = Path.of(args[0]); JsonObject config = new Gson().fromJson(Files.readString(configPath), JsonObject.class);
        Path directory = configPath.getParent().resolve("java"); Files.createDirectories(directory);
        String name = "java_items"; BigInteger object = BigInteger.ONE.shiftLeft(64).subtract(n(2));
        check(Catalog.class.getProtectionDomain().getCodeSource().getLocation().toString().contains("transit-station-sdk-" + Catalog.class.getPackage().getImplementationVersion() + ".jar"));
        try (Catalog.Client client = connect(config); Scanner input = new Scanner(System.in, StandardCharsets.UTF_8)) {
            System.out.println(obj("ready", true));
            while (input.hasNextLine()) {
                JsonObject action = new Gson().fromJson(input.nextLine(), JsonObject.class); String command = action.keySet().iterator().next(); if (command.equals("close")) break;
                JsonObject result;
                switch (command) {
                    case "prepare" -> {
                        check(await(client.describe()).subject().principal() == config.getAsJsonObject("connection").get("principal").getAsLong());
                        check(await(client.namespace(1)).orElseThrow().name().equals("public")); check(await(client.namespaces()).entries().stream().anyMatch(v -> v.id() == 1));
                        complete(client, await(client.compileSql("CREATE TABLE " + name + " (id BIGINT PRIMARY KEY, payload BINARY)", new Identity(n(1)), Optional.of(object))), directory);
                        Metadata current = await(client.lookup(name)).orElseThrow(); check(current.rowCount().signum() == 0 && current.basis().object().equals(object));
                        List<List<Assignment>> rows = new ArrayList<>();
                        for (int i=0; i<9; i++) {
                            byte[] bytes = new byte[32768]; Arrays.fill(bytes, (byte)i);
                            rows.add(List.of(new Assignment(n(1), new Logical.Present(new Logical.Signed(n(i)))), new Assignment(n(2), new Logical.Present(new Logical.Binary(new Logical.BinaryData(bytes))))));
                        }
                        Compiled work = await(client.prepare(name, new Identity(n(2)), new Mutate(current.basis(), new Insert(rows), Ingestion.BULK)));
                        check(((CurrentBasis)await(client.preview(work.intent())).current().orElseThrow()).rowCount().signum() == 0);
                        persist(directory.resolve("intent.json"), work.saved().save()); Intent loaded = await(client.load(SavedIntent.restore(Files.readString(directory.resolve("intent.json")))));
                        Reference original = await(client.stage(loaded)); persist(directory.resolve("original.json"), original.save());
                        check(await(client.admit(original)).state() == OperationState.ADMITTED); uncertain(original, () -> await(client.execute(original, 32)));
                        result = obj("uncertain", true);
                    }
                    case "recover" -> {
                        Reference original = Reference.restore(Files.readString(directory.resolve("original.json"))); Observation observed = await(client.inspect(original));
                        Commit committed = observed.commit().orElseThrow(); check(observed.state() == OperationState.COMMITTED && List.of(committed.matched(), committed.affected(), committed.liveRows()).equals(List.of(n(9),n(9),n(9))));
                        check(await(client.execute(original, 32)).equals(observed)); Metadata current = await(client.lookup(name)).orElseThrow();
                        SnapshotAcquisition acquisition = client.prepareSnapshot(current, n(90000)); persist(directory.resolve("basis.json"), current.basis().save()); persist(directory.resolve("acquisition.json"), acquisition.save());
                        uncertain(acquisition, () -> await(client.acquireSnapshot(acquisition))); result = obj("retention_uncertain", true);
                    }
                    case "retained" -> {
                        SnapshotAcquisition acquisition = SnapshotAcquisition.restore(Files.readString(directory.resolve("acquisition.json"))); SnapshotStatus status = await(client.snapshotStatus(acquisition.owner()));
                        check(!status.released() && status.snapshot().isPresent()); Snapshot snapshot = status.snapshot().orElseThrow(); persist(directory.resolve("snapshot.json"), snapshot.save());
                        SnapshotMetadata metadata = await(client.snapshotMetadata(snapshot)); check(metadata.accepted().equals(acquisition.expected()) && metadata.rowCount().equals(n(9)) && metadata.schema().columns().size() == 2);
                        result = obj("retained", true);
                    }
                    case "denied" -> {
                        try { await(client.snapshotMetadata(snapshot(directory))); throw new AssertionError("Revoked retained metadata disclosed"); }
                        catch (TransitException error) { check(error.kind() == TransitException.Kind.ACCESS_DENIED && error.status() == 4 && error.diagnostic().get("category").getAsString().equals("access")); }
                        result = obj("denied", true);
                    }
                    case "metadata" -> {
                        SnapshotMetadata metadata = await(client.snapshotMetadata(snapshot(directory))); Basis basis = Basis.restore(Files.readString(directory.resolve("basis.json")));
                        check(metadata.interpretation().equals(basis.interpretation())); result = obj("rows", metadata.rowCount(), "columns", metadata.schema().columns().size());
                    }
                    case "retire" -> {
                        Commit unchanged = complete(client, compile(client, "UPDATE " + name + " SET id=0 WHERE id=0", 3), directory).commit().orElseThrow(); check(unchanged.matched().equals(n(1)) && unchanged.affected().equals(n(0)));
                        Commit deleted = complete(client, compile(client, "DELETE FROM " + name + " WHERE id=8", 4), directory).commit().orElseThrow(); check(deleted.matched().equals(n(1)) && deleted.affected().equals(n(1)));
                        Metadata old = await(client.lookup(name)).orElseThrow();
                        complete(client, await(client.prepare(name, new Identity(n(5)), new Alter(old.basis(), new AddColumn("extra", Logical.Scalar.INT64)))), directory);
                        try { await(client.prepare(name, new Identity(n(55)), new Drop(old.basis()))); throw new AssertionError("Stale basis retargeted newer definition"); }
                        catch (TransitException error) { check(error.code().equals("TableDefinitionChanged")); }
                        complete(client, compile(client, "ALTER TABLE " + name + " RENAME TO " + name + "_old", 6), directory);
                        complete(client, compile(client, "DROP TABLE " + name + "_old", 7), directory);
                        complete(client, await(client.compileSql("CREATE TABLE " + name + " (replacement BIGINT)", new Identity(n(8)), Optional.of(object.subtract(n(1))))), directory);
                        check(await(client.lookup(name)).orElseThrow().basis().object().equals(object.subtract(n(1))) && await(client.snapshotMetadata(snapshot(directory))).rowCount().equals(n(9)));
                        result = obj("original", true);
                    }
                    case "release" -> {
                        Snapshot snapshot = snapshot(directory); check(!await(client.snapshotStatus(snapshot.owner())).released());
                        uncertain(snapshot, () -> await(client.releaseSnapshot(snapshot))); result = obj("release_uncertain", true);
                    }
                    case "verify" -> {
                        Snapshot snapshot = snapshot(directory); check(await(client.snapshotStatus(snapshot.owner())).released()); await(client.releaseSnapshot(snapshot));
                        Reference original = Reference.restore(Files.readString(directory.resolve("original.json"))); check(await(client.inspect(original)).commit().orElseThrow().affected().equals(n(9)));
                        check(await(client.load(SavedIntent.restore(Files.readString(directory.resolve("intent.json"))))).identity().operation().equals(n(2)));
                        check(await(client.lookup(name)).orElseThrow().basis().object().equals(object.subtract(n(1))) && await(client.tables()).consistency().orElseThrow() == Consistency.INDEPENDENT);
                        result = obj("recovered", true);
                    }
                    default -> throw new AssertionError("Unknown proof phase: " + command);
                }
                System.out.println(obj("status", 0, "value", result));
            }
        }
        System.out.println(obj("closed", true));
    }
}
