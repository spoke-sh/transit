import com.google.gson.*;
import io.transit.client.*;
import io.transit.client.internal.Values;
import io.transit.sdk.station.*;
import io.transit.sdk.station.Types.*;
import io.transit.examples.*;
import io.transit.examples.Messages.*;
import java.io.*;
import java.math.BigInteger;
import java.net.URI;
import java.nio.*;
import java.nio.channels.FileChannel;
import java.nio.file.*;
import java.nio.file.attribute.PosixFilePermissions;
import java.util.*;
import java.util.concurrent.*;
import java.util.concurrent.atomic.AtomicReference;
import static io.transit.client.internal.Worker.await;

public final class JavaStationSdk {
    private JavaStationSdk() {}
    static void check(boolean value) { if (!value) throw new AssertionError("Java Station proof failed"); }
    static void expect(TransitException.Kind kind, Runnable action) {
        try { action.run(); } catch (TransitException error) {
            if (error.kind() != kind) throw new AssertionError("Expected " + kind + " but got " + error.kind() + " status=" + error.status() + " code=" + error.code() + " phase=" + error.phase());
            return;
        }
        throw new AssertionError("Expected " + kind);
    }
    static JsonObject read(Path path) {
        try { return Values.object(Values.parse(Files.readAllBytes(path))); }
        catch (IOException error) { throw new UncheckedIOException(error); }
    }
    static void write(Path path, JsonObject value) {
        try { Files.writeString(path, value.toString()); }
        catch (IOException error) { throw new UncheckedIOException(error); }
    }
    static void report(JsonObject value) { System.out.println(value); System.out.flush(); }
    static void sleep(long millis) { try { Thread.sleep(millis); } catch (InterruptedException error) { Thread.currentThread().interrupt(); throw new AssertionError("Interrupted proof"); } }
    static void waitFile(Path path) {
        long deadline = System.nanoTime() + TimeUnit.SECONDS.toNanos(30);
        while (!Files.exists(path)) { check(System.nanoTime() < deadline); sleep(10); }
    }
    static void otherThread(Runnable action) {
        AtomicReference<Throwable> failed = new AtomicReference<>();
        Thread thread = new Thread(() -> { try { action.run(); } catch (Throwable error) { failed.set(error); } });
        thread.start();
        try { thread.join(); } catch (InterruptedException error) { Thread.currentThread().interrupt(); throw new AssertionError("Interrupted proof"); }
        if (failed.get() instanceof RuntimeException error) throw error;
        if (failed.get() instanceof Error error) throw error;
    }
    static final class CounterProof extends Handlers.Counter {
        final String mode;
        int initialized, handled;
        io.transit.sdk.station.State escaped;
        CounterProof(String mode) { this.mode = mode; }
        @Override public void initialize(Turn turn) {
            initialized++; check(turn.budgets().mutations() == 3);
            if (mode.equals("thread-handler")) { otherThread(() -> turn.state().put(Handlers.TOTAL, BigInteger.valueOf(73))); return; }
            super.initialize(turn);
        }
        @Override public void onMessage(Turn turn, Incoming<CounterMessage> input) {
            handled++; escaped = turn.state();
            otherThread(() -> expect(TransitException.Kind.BUSY, () -> escaped.require(Handlers.TOTAL)));
            if (mode.startsWith("handler-") || mode.startsWith("error-")) {
                turn.state().put(Handlers.TOTAL, BigInteger.valueOf(73));
                if (mode.startsWith("error-")) throw new AssertionError("Injected handler error");
                throw new IllegalStateException("Injected handler exception");
            }
            if (mode.equals("poison")) { expect(TransitException.Kind.READ_FAILED, () -> turn.state().require(Handlers.TOTAL)); return; }
            // A reentrant application codec cannot enter another scoped operation.
            Codec<BigInteger> reentrant = new Codec<>() {
                @Override public String typeId() { return Codecs.U64.typeId(); }
                @Override public long version() { return 1; }
                @Override public int maxEncodedBytes() { return 12; }
                @Override public byte[] encode(BigInteger value) { throw new AssertionError("Unused"); }
                @Override public BigInteger decode(byte[] bytes) {
                    expect(TransitException.Kind.BUSY, turn::budgets); return Codecs.U64.decode(bytes);
                }
            };
            turn.state().require(new Key<>("total", reentrant));
            super.onMessage(turn, input);
        }
    }
    static final class TableProof extends Handlers.TableService {
        final Path output;
        Table<Long> escaped;
        Source source;
        TableProof(ProcessRef peer, Path output) { super(peer); this.output = output; }
        @Override public void onMessage(Turn turn, Incoming<QueryMessage> input) {
            Path saved = output.resolve("version.json");
            if (input instanceof Cast<QueryMessage> && input.value() instanceof Rows) {
                Table<Long> table = turn.table(Handlers.TABLE); escaped = table;
                Cursor cursor = null; List<Table.Row<Long>> rows = new ArrayList<>(); int pages = 0;
                do {
                    Page<Table.Row<Long>> page = table.page(cursor);
                    check(page.entries().size() <= 8 && page.basis().equals(table.basis()));
                    rows.addAll(page.entries()); pages++; cursor = page.cursor();
                } while (cursor != null);
                check(rows.size() == 41 && pages == 6 && rows.getFirst().key() == Long.MIN_VALUE && rows.getFirst().value() == null);
                ReadVersion version = turn.retain();
                write(saved, Values.obj("pid", version.pid(), "input", version.input(), "index", version.index()));
                table.update(new Table.Row<>(Long.MIN_VALUE, 17L));
            } else if (input.value() instanceof Initialize && Files.exists(saved)) {
                JsonObject savedVersion = read(saved);
                ReadVersion version = new ReadVersion(savedVersion.get("pid").getAsLong(), savedVersion.get("input").getAsLong(), savedVersion.get("index").getAsInt());
                check(turn.table(Handlers.TABLE).get(Long.MIN_VALUE).orElseThrow().value() == 17L);
                source = turn.openVersion(version);
                check(source.table(Handlers.TABLE).get(Long.MIN_VALUE).orElseThrow().value() == null);
                check(source.table(Handlers.TABLE).page().entries().size() == 8 && source.state().page().entries().size() <= 8);
                turn.release(version);
            } else super.onMessage(turn, input);
        }
        void expired() {
            if (escaped != null) expect(TransitException.Kind.TURN_EXPIRED, () -> escaped.get(0));
            if (source != null) expect(TransitException.Kind.TURN_EXPIRED, source::state);
        }
    }
    static final class QueryProof extends Handlers.QueryRequester {
        final Path output;
        final List<Query.IpcSegment> owned;
        Query.ResultReader escaped;
        QueryProof(ProcessRef peer, Path output) { this(peer, output, new ArrayList<>()); }
        private QueryProof(ProcessRef peer, Path output, List<Query.IpcSegment> owned) { super(peer, owned::add); this.output = output; this.owned = owned; }
        @Override public void onMessage(Turn turn, Incoming<QueryMessage> input) {
            Path saved = output.resolve("manifest.json");
            if (Files.exists(saved)) {
                Query.ResultReader reader = turn.result(new BigInteger(read(saved).get("correlation").getAsString()));
                check(reader.manifest().rows().equals(BigInteger.valueOf(41)));
                try { Files.writeString(output.resolve("ready"), ""); } catch (IOException error) { throw new UncheckedIOException(error); }
                waitFile(output.resolve("continue")); reader.segment(BigInteger.ZERO);
            } else super.onMessage(turn, input);
        }
        @Override public void onResult(Turn turn, ResultComplete complete) {
            super.onResult(turn, complete);
            escaped = turn.result(complete.correlation()); Query.Manifest manifest = escaped.manifest();
            write(output.resolve("manifest.json"), Values.obj("rows", manifest.rows(), "segments", manifest.segments(), "correlation", manifest.correlation().toString(),
                "source", manifest.source().pid(), "destination", manifest.destination().pid(), "resource", manifest.basis().resource().resource(),
                "revision", manifest.basis().revision(), "bytes", manifest.byteCount()));
        }
        void saveOwned() throws IOException {
            if (escaped != null) expect(TransitException.Kind.TURN_EXPIRED, escaped::manifest);
            for (Query.IpcSegment segment : owned) {
                byte[] original = segment.ipc(); segment.ipc()[0] ^= 1; check(Arrays.equals(original, segment.ipc()));
                Files.write(output.resolve(segment.ordinal() + ".arrow"), original);
            }
        }
    }
    static final class Store implements Recovery.Store {
        final String mode; final Path pending;
        Runner<?> runner;
        final Set<Purpose> beforeFailed = EnumSet.noneOf(Purpose.class), confirmFailed = EnumSet.noneOf(Purpose.class);
        final Map<OperationIdentity, byte[]> saved = new HashMap<>();
        final Map<OperationIdentity, io.transit.client.Outcomes.MutationReceipt> confirmations = new HashMap<>();
        FrozenMutation current;
        Store(String mode, Path pending) { this.mode = mode; this.pending = pending; }
        @Override public void beforeDispatch(FrozenMutation mutation) {
            current = mutation;
            if (mode.equals("gates")) {
                expect(TransitException.Kind.BUSY, () -> await(runner.next()));
                expect(TransitException.Kind.BUSY, runner::close);
                expect(TransitException.Kind.BUSY, runner::closeAsync);
                if (beforeFailed.add(mutation.purpose())) {
                    if (mutation.purpose() == Purpose.PERMIT) throw new AssertionError("Persistence error");
                    throw new IllegalStateException("Persistence exception");
                }
            }
            byte[] bytes = mutation.export();
            if (saved.containsKey(mutation.identity())) check(Arrays.equals(saved.get(mutation.identity()), bytes));
            saved.put(mutation.identity(), bytes);
            try {
                if (!Files.exists(pending)) Files.createFile(pending, PosixFilePermissions.asFileAttribute(PosixFilePermissions.fromString("rw-------")));
                try (FileChannel file = FileChannel.open(pending, StandardOpenOption.WRITE, StandardOpenOption.TRUNCATE_EXISTING)) {
                    ByteBuffer data = ByteBuffer.wrap(bytes); while (data.hasRemaining()) file.write(data); file.force(true);
                }
                try (FileChannel directory = FileChannel.open(pending.getParent(), StandardOpenOption.READ)) { directory.force(true); }
            } catch (IOException error) { throw new UncheckedIOException(error); }
        }
        @Override public void confirmed(OperationIdentity identity, io.transit.client.Outcomes.MutationReceipt receipt) {
            check(saved.containsKey(identity) && receipt.position() > 0);
            if (mode.equals("gates") && confirmFailed.add(current.purpose())) {
                if (current.purpose() == Purpose.OPEN) throw new AssertionError("Confirmation error");
                throw new IllegalStateException("Confirmation exception");
            }
            confirmations.put(identity, receipt);
        }
    }
    static <T> void roundtrip(Codec<T> codec, byte[] bytes) { check(Arrays.equals(codec.encode(codec.decode(bytes)), bytes)); }
    static void codecs(JsonObject cfg) {
        Codec<CounterMessage> counter = new Codecs.CounterCodec(Set.of(Add.class, Read.class, Start.class, Total.class));
        Codec<QueryMessage> query = new Codecs.QueryCodec(Set.of(Initialize.class, Insert.class, Rows.class, Start.class));
        JsonObject fixtures = read(Path.of(cfg.get("fixtures").getAsString()));
        for (JsonElement item : fixtures.getAsJsonArray("valid")) {
            JsonObject fixture = item.getAsJsonObject(); byte[] bytes = HexFormat.of().parseHex(fixture.get("hex").getAsString());
            switch (fixture.get("codec").getAsString()) {
                case "u64" -> { roundtrip(Codecs.U64, bytes); check(Codecs.U64.decode(bytes).equals(new BigInteger(fixture.get("value").getAsString()))); }
                case "counter" -> {
                    roundtrip(counter, bytes); CounterMessage decoded = counter.decode(bytes);
                    check(decoded.getClass().getSimpleName().equals(fixture.get("variant").getAsString()));
                    if (decoded instanceof Add add) check(add.value().equals(new BigInteger(fixture.get("value").getAsString())));
                    if (decoded instanceof Total total) check(total.value().equals(new BigInteger(fixture.get("value").getAsString())));
                }
                case "query" -> {
                    roundtrip(query, bytes); QueryMessage decoded = query.decode(bytes);
                    check(decoded.getClass().getSimpleName().equals(fixture.get("variant").getAsString()));
                    if (decoded instanceof Insert insert) {
                        check(insert.key() == Long.parseLong(fixture.get("key").getAsString()));
                        check(Objects.equals(insert.value(), !fixture.has("value") || fixture.get("value").isJsonNull() ? null : Long.valueOf(fixture.get("value").getAsString())));
                    }
                }
                default -> throw new AssertionError("Unknown codec fixture");
            }
        }
        for (JsonElement item : fixtures.getAsJsonArray("invalid")) {
            JsonObject fixture = item.getAsJsonObject(); byte[] bytes = HexFormat.of().parseHex(fixture.get("hex").getAsString());
            try {
                switch (fixture.get("codec").getAsString()) { case "u64" -> Codecs.U64.decode(bytes); case "counter" -> counter.decode(bytes); case "query" -> query.decode(bytes); default -> throw new AssertionError("Unknown codec"); }
                throw new AssertionError("Invalid payload accepted");
            } catch (IllegalArgumentException | BufferUnderflowException expected) { }
        }
        Add value = new Add(BigInteger.ONE.shiftLeft(53).add(BigInteger.ONE));
        byte[] expected = ByteBuffer.allocate(26).order(ByteOrder.LITTLE_ENDIAN).put(new byte[]{'S','T','N','1',1}).putLong(0).put(Codecs.COUNTER.encode(value)).array();
        check(Arrays.equals(expected, Station.encodeCast(value, Codecs.COUNTER)));
        expect(TransitException.Kind.INCOMPATIBLE_NATIVE, () -> Station.encodeCast(value, Codecs.COUNTER, Path.of(cfg.get("fixtures").getAsString()).getParent().resolve("bad-station-version")));
        check(counter.typeId().equals("transit.examples.counter") && query.typeId().equals("transit.examples.query") && Codecs.U64.typeId().equals("transit.examples.u64"));
    }
    static <T> void execute(String mode, JsonObject cfg, Handler<T> handler, Codec<T> codec) throws Exception {
        long realm = cfg.get("realm").getAsLong();
        ServiceConfig config = new ServiceConfig(new ClientConfig(URI.create(cfg.get("url").getAsString()), ClientConfig.Profile.GROWING_V3),
            new Activation(new ProcessRef(realm, cfg.get("pid").getAsLong()), cfg.get("generation").getAsLong(),
                new Credential(realm, cfg.get("principal").getAsLong(), Path.of(cfg.get("seed_file").getAsString()))), "data", cfg.get("query_results").getAsBoolean());
        Store store = new Store(mode, Path.of(cfg.get("pending").getAsString()));
        FailurePolicy failure = mode.endsWith("-block") ? FailurePolicy.BLOCK_INPUT : FailurePolicy.STOP;
        Recovery recovery = new Recovery.PersistBeforeDispatch(store);
        if (mode.equals("denied")) { expect(TransitException.Kind.ACCESS_DENIED, () -> Runner.open(config, handler, codec, failure, recovery)); return; }
        try (Runner<T> runner = Runner.open(config, handler, codec, failure, recovery)) {
            store.runner = runner;
            if (mode.equals("gates")) {
                Set<String> phases = new HashSet<>(); boolean done = false;
                for (int count = 0; count < 40; count++) {
                    Event event = await(runner.next());
                    if (event instanceof NeedsRecovery paused) {
                        phases.add(paused.phase()); if (paused.phase().equals("confirm")) check(paused.receipt() != null);
                        check(await(runner.next()) == event); event = await(runner.reconcile());
                    }
                    if (event instanceof Committed) { done = true; break; }
                }
                check(done && phases.equals(Set.of("persist", "confirm")) && store.confirmations.size() == 3);
                CounterProof counter = (CounterProof) handler;
                check(counter.initialized == 1 && counter.handled == 1);
                expect(TransitException.Kind.TURN_EXPIRED, () -> counter.escaped.require(Handlers.TOTAL));
                JsonArray gates = new JsonArray(); store.confirmFailed.stream().map(p -> p.name().toLowerCase(Locale.ROOT)).sorted().forEach(gates::add);
                report(Values.obj("gates", gates, "handled", counter.handled, "dispatches", store.saved.size()));
            } else if (mode.equals("async")) {
                check(!(await(runner.next()) instanceof Committed));
                AtomicReference<CompletableFuture<Event>> waiting = new AtomicReference<>();
                AtomicReference<Throwable> failed = new AtomicReference<>();
                Thread controller = new Thread(() -> {
                    try { for (;;) { CompletableFuture<Event> future = runner.next(); waiting.set(future); if (await(future) instanceof Committed) throw new AssertionError("Expected cancelled wait"); } }
                    catch (CancellationException expected) { }
                    catch (Throwable error) { failed.set(error); }
                });
                controller.start(); waitFile(Path.of(cfg.get("output").getAsString()).resolve("accepted"));
                expect(TransitException.Kind.BUSY, () -> await(runner.next())); check(waiting.get().cancel(true)); controller.join(); check(failed.get() == null);
                runner.stop(); CompletableFuture<Shutdown> closing = runner.closeAsync(); int beats = 0;
                while (!closing.isDone()) { beats++; sleep(10); }
                Shutdown evidence = await(closing);
                check(beats > 5 && evidence.pending() == null && evidence.lastEvent() instanceof Committed && ((CounterProof) handler).handled == 1);
                report(Values.obj("committed", true, "beats", beats));
            } else if (mode.startsWith("decode-") || mode.startsWith("handler-") || mode.startsWith("error-") || mode.equals("thread-handler")) {
                boolean stopped = false;
                for (int count = 0; count < 8; count++) {
                    try {
                        Event event = await(runner.next());
                        if (event instanceof Blocked blocked) { check(mode.endsWith("-block") && blocked.receipt() != null); stopped = true; break; }
                    } catch (TransitException error) {
                        check(!mode.endsWith("-block"));
                        TransitException.Kind expected = mode.startsWith("decode-") ? TransitException.Kind.CODEC : mode.equals("thread-handler") ? TransitException.Kind.BUSY : TransitException.Kind.HANDLER;
                        if (error.kind() != expected) throw new AssertionError(mode + " expected " + expected + " but got " + error.kind() + " status=" + error.status() + " code=" + error.code() + " phase=" + error.phase());
                        stopped = true; break;
                    }
                }
                check(stopped);
            } else if (Set.of("stale", "expired", "revoked-result", "poison").contains(mode)) {
                TransitException.Kind expected = switch (mode) { case "stale" -> TransitException.Kind.STALE_OWNERSHIP; case "expired" -> TransitException.Kind.PROCESS_RETIRED; case "revoked-result" -> TransitException.Kind.ACCESS_DENIED; default -> TransitException.Kind.READ_FAILED; };
                expect(expected, () -> { for (int count = 0; count < 8; count++) await(runner.next()); }); report(Values.obj("denied", true));
            } else {
                BufferedReader input = new BufferedReader(new InputStreamReader(System.in, java.nio.charset.StandardCharsets.UTF_8));
                for (String line; (line = input.readLine()) != null;) {
                    if (line.equals("close")) {
                        runner.closeSnapshot();
                        if (handler instanceof QueryProof query) query.saveOwned();
                        if (handler instanceof TableProof table) table.expired();
                        report(Values.obj("closed", true)); break;
                    }
                    check(line.equals("one")); Event event = null;
                    for (int count = 0; count < 32; count++) { event = await(runner.next()); if (!(event instanceof Progress)) break; }
                    if (event instanceof NeedsRecovery paused) check(Arrays.equals(paused.mutation().export(), Files.readAllBytes(store.pending)));
                    report(Values.obj("event", Objects.requireNonNull(event).getClass().getSimpleName()));
                }
            }
        }
    }
    public static void main(String[] args) throws Exception {
        String mode = args[0]; Path path = Path.of(args[1]); JsonObject cfg = read(path);
        check(Path.of(Runner.class.getProtectionDomain().getCodeSource().getLocation().toURI()).startsWith(path.getParent()));
        check(cfg.get("profile").getAsString().equals("growing_v3"));
        if (mode.equals("codecs")) { codecs(cfg); return; }
        if (mode.equals("recover")) {
            try (Client client = Client.open(new ClientConfig(URI.create(cfg.get("url").getAsString()), ClientConfig.Profile.GROWING_V3));
                 PendingMutation pending = await(client.recoverMutation(Files.readAllBytes(Path.of(cfg.get("pending").getAsString()))))) {
                var result = await(client.dispatchMutation(pending)); check(result instanceof io.transit.client.Outcomes.Confirmed);
                report(Values.obj("receipt", ((io.transit.client.Outcomes.Confirmed) result).receipt().position()));
            }
            return;
        }
        ProcessRef peer = new ProcessRef(cfg.get("realm").getAsLong(), cfg.get("peer").getAsLong()); Path output = Path.of(cfg.get("output").getAsString());
        switch (cfg.get("role").getAsString()) {
            case "service" -> execute(mode, cfg, new CounterProof(mode), Codecs.COUNTER);
            case "requester" -> execute(mode, cfg, new Handlers.Requester(peer), Codecs.REQUESTER);
            case "table" -> execute(mode, cfg, new TableProof(peer, output), Codecs.QUERY_SERVICE);
            case "query" -> execute(mode, cfg, new QueryProof(peer, output), Codecs.QUERY_REQUESTER);
            default -> throw new AssertionError("Unknown role");
        }
    }
}
