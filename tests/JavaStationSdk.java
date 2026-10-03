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
        JsonObject http = read(Path.of(cfg.get("http_fixtures").getAsString()));
        Http.Prepared request = Http.prepare(new ResourceRef(72, 8), Values.U64_MAX, new Http.Request(Http.Method.POST, List.of(new Http.Literal("/write")), List.of()),
            HexFormat.of().parseHex(http.get("body").getAsString()), new Http.Options(BigInteger.valueOf(7), 9000, 2));
        check(HexFormat.of().formatHex(request.reference().copy()).equals(http.get("reference").getAsString()));
        check(Values.text(request.metadata().copy()).equals(http.get("metadata").getAsString()));
        byte[] encoded = HexFormat.of().parseHex(http.get("outcome").getAsString());
        Http.Outcome outcome = (Http.Outcome)Http.decodeReply(72, encoded);
        check(outcome.exchange().equals(Values.U64_MAX) && outcome.status().orElseThrow() == 200 && outcome.phase() == Http.Phase.OBSERVED && outcome.reference().isPresent());
        check(((Http.Outcome)Http.decodeReply(72, HexFormat.of().parseHex(http.get("outcome").getAsString()))).diagnostic().get("code").getAsString().equals("http.response_observed"));
        check(((Http.Rejected)Http.decodeReply(72, HexFormat.of().parseHex(http.get("rejection").getAsString()))).reason() == Http.Rejection.DENIED);
        Http.ReplyCodec<BigInteger> codec = new Http.ReplyCodec<>(Codecs.U64, 72);
        check(((Http.Application<BigInteger>)codec.decode(codec.encode(new Http.Application<>(Values.U64_MAX)))).value().equals(Values.U64_MAX));
        check(((Http.Outcome)((Http.Received<BigInteger>)codec.decode(encoded)).value()).exchange().equals(Values.U64_MAX));
        expect(TransitException.Kind.CODEC, () -> codec.encode(new Http.Received<>(outcome)));
        byte[] releasedBytes = HexFormat.of().parseHex(read(Path.of(cfg.get("http_release_fixtures").getAsString())).get("reply").getAsString());
        Http.Released released = (Http.Released)((Http.Received<BigInteger>)codec.decode(releasedBytes)).value();
        check(released.equals(new Http.Released(new ResourceRef(72, 7), Values.U64_MAX)));
        expect(TransitException.Kind.CODEC, () -> codec.encode(new Http.Received<>(released)));
        try { Http.decodeReply(72, Arrays.copyOf(releasedBytes, 19)); throw new AssertionError("Truncated acknowledgement accepted"); } catch (TransitException expectedFailure) { }
        try { Http.decodeReply(72, Arrays.copyOf(encoded, 70)); throw new AssertionError("Truncated HTTP outcome accepted"); } catch (TransitException expectedFailure) { }
        try { Http.prepare(new ResourceRef(72, 8), BigInteger.ONE, new Http.Request(Http.Method.GET, List.of(new Http.Literal("//other/")), List.of()),
            new byte[0], new Http.Options(BigInteger.ONE, 9000, 1)); throw new AssertionError("Invalid HTTP target accepted"); } catch (TransitException expectedFailure) { }
    }
    static final class HttpBytes implements Codec<Bytes> {
        public String typeId() { return "test.http-control"; }
        public long version() { return 1; }
        public int maxEncodedBytes() { return 243; }
        public byte[] encode(Bytes value) { return value.copy(); }
        public Bytes decode(byte[] value) { return new Bytes(value); }
    }
    static final class HttpHandler implements Handler<Http.Message<Bytes>> {
        final ProcessRef peer;
        final Http.Prepared request;
        final Key<BigInteger> correlation = new Key<>("http-correlation", Codecs.U64);
        final Key<BigInteger> releaseCorrelation = new Key<>("http-release-correlation", Codecs.U64);
        final Key<BigInteger> followupCorrelation = new Key<>("http-followup-correlation", Codecs.U64);
        final Http.Outcome disposal;
        final Http.Outcome wrongParent;
        final Http.FollowupReason reason;
        Turn escaped;
        JsonObject result;
        HttpHandler(ProcessRef peer, Http.Prepared request, Http.Outcome disposal, Http.Outcome wrongParent, Http.FollowupReason reason) { this.peer = peer; this.request = request; this.disposal = disposal; this.wrongParent = wrongParent; this.reason = reason; }
        @Override public void onMessage(Turn turn, Incoming<Http.Message<Bytes>> input) {
            escaped = turn;
            if (input instanceof Cast<Http.Message<Bytes>>) {
                if (input.value() instanceof Http.Application<Bytes> application && Arrays.equals(application.value().copy(), "followup".getBytes(java.nio.charset.StandardCharsets.US_ASCII))) {
                    expect(TransitException.Kind.HANDLER, () -> turn.followupHttp(peer, wrongParent, reason, request));
                    BigInteger id = turn.followupHttp(peer, disposal, reason, request);
                    turn.state().put(followupCorrelation, id); result = Values.obj("followup", false);
                } else if (input.value() instanceof Http.Application<Bytes> application && Arrays.equals(application.value().copy(), "dispose".getBytes(java.nio.charset.StandardCharsets.US_ASCII))) {
                    expect(TransitException.Kind.HANDLER, () -> turn.releaseHttp(peer, new ResourceRef(73, disposal.resource().resource()), disposal.exchange()));
                    BigInteger id = turn.releaseHttp(peer, disposal.resource(), disposal.exchange());
                    turn.state().put(releaseCorrelation, id); result = Values.obj("released", false);
                } else if (turn.state().find(correlation).isPresent()) result = Values.obj("called", true);
                else if (turn.stageHttp(request)) { BigInteger id = turn.callHttp(peer, request); turn.state().put(correlation, id); result = Values.obj("called", true); }
                else result = Values.obj("called", false);
            } else {
                check(input instanceof Reply<Http.Message<Bytes>>);
                if (((Http.Received<Bytes>)input.value()).value() instanceof Http.Rejected rejected) {
                    BigInteger id = turn.state().require(followupCorrelation);
                    turn.requireReply((Reply<?>)input, peer, id); check(rejected.reason() == Http.Rejection.DENIED);
                    turn.state().put(new Key<>("http-followup-denied", Codecs.U64), id); result = Values.obj("followup", true); return;
                }
                if (((Http.Received<Bytes>)input.value()).value() instanceof Http.Released released) {
                    turn.requireReply((Reply<?>)input, peer, turn.state().require(releaseCorrelation));
                    check(released.resource().equals(disposal.resource()) && released.exchange().equals(disposal.exchange()));
                    turn.state().put(new Key<>("http-disposed", Codecs.U64), released.exchange()); result = Values.obj("released", true); return;
                }
                turn.requireReply((Reply<?>)input, peer, turn.state().require(correlation));
                Http.Outcome outcome = (Http.Outcome)((Http.Received<Bytes>)input.value()).value();
                check(outcome.phase() == Http.Phase.OBSERVED && outcome.status().orElseThrow() == 200);
                turn.state().put(new Key<>("http-status", Codecs.U64), BigInteger.valueOf(200)); result = Values.obj("observed", true);
            }
        }
    }
    static void http(String mode, JsonObject cfg) throws IOException {
        byte[] body = HexFormat.of().parseHex(cfg.get("body").getAsString());
        Http.Prepared request = Http.prepare(new ResourceRef(72, cfg.get("resource").getAsLong()), Values.U64_MAX,
            new Http.Request(Http.Method.POST, List.of(new Http.Literal("/items/"), new Http.Variable("id", "λ /")), List.of(
                new Http.Header("X-Tag", List.of(new Http.Literal("one"))), new Http.Header("X-Tag", List.of(new Http.Literal("two"))),
                new Http.Header("Authorization", List.of(new Http.Literal("Bearer "), new Http.SecretRef("api", BigInteger.valueOf(7)))))),
            body, new Http.Options(BigInteger.valueOf(7), cfg.get("deadline").getAsLong(), 1));
        byte original = request.body().copy()[0]; body[0] ^= 127; byte[] copy = request.body().copy(); copy[0] ^= 1;
        check(request.body().copy()[0] == original && request.body().size() == 513);
        ServiceConfig config = new ServiceConfig(new ClientConfig(URI.create(cfg.get("url").getAsString()), ClientConfig.Profile.NATIVE_V1),
            new Activation(new ProcessRef(72, cfg.get("pid").getAsLong()), cfg.get("generation").getAsLong(),
                new Credential(72, cfg.get("principal").getAsLong(), Path.of(cfg.get("seed_file").getAsString()))));
        Http.Outcome disposal = cfg.has("outcome") ? (Http.Outcome)Http.decodeReply(72, HexFormat.of().parseHex(cfg.get("outcome").getAsString())) : null;
        Http.Outcome wrongParent = cfg.has("outcome") ? (Http.Outcome)Http.decodeReply(73, HexFormat.of().parseHex(cfg.get("outcome").getAsString())) : null;
        Http.FollowupReason reason = cfg.has("followup_reason") ? Http.FollowupReason.valueOf(cfg.get("followup_reason").getAsString().toUpperCase(Locale.ROOT)) : Http.FollowupReason.RETRY;
        HttpHandler handler = new HttpHandler(new ProcessRef(72, cfg.get("peer").getAsLong()), request, disposal, wrongParent, reason);
        ByteArrayOutputStream owned = new ByteArrayOutputStream(); Http.Reader reader = null; Http.Outcome outcome = null;
        try (Runner<Http.Message<Bytes>> runner = Runner.open(config, handler, new Http.ReplyCodec<>(new HttpBytes(), 72), FailurePolicy.STOP, new Recovery.FreshOwnership())) {
            if (mode.equals("http-async")) {
                Http.Reader active = await(runner.openHttp((Http.Outcome)Http.decodeReply(72, HexFormat.of().parseHex(cfg.get("outcome").getAsString()))));
                Http.Part first = await(active.read()).orElseThrow(); check(first.data().size() > 0 && !first.complete());
                Files.writeString(Path.of(cfg.get("ready").getAsString()), ""); waitFile(Path.of(cfg.get("continue").getAsString()));
                CompletableFuture<Optional<Http.Part>> pending = active.read(); waitFile(Path.of(cfg.get("accepted").getAsString()));
                expect(TransitException.Kind.BUSY, () -> await(active.read())); check(pending.cancel(true));
                runner.stop(); CompletableFuture<Shutdown> closing = runner.closeAsync(); int beats = 0;
                while (!closing.isDone()) { beats++; sleep(10); } await(closing); check(beats > 5 && first.data().size() > 0);
                expect(TransitException.Kind.CLOSED, () -> await(active.read())); report(Values.obj("joined", true)); return;
            }
            BufferedReader input = new BufferedReader(new InputStreamReader(System.in, java.nio.charset.StandardCharsets.UTF_8));
            for (String line; (line = input.readLine()) != null;) {
                switch (line) {
                    case "step" -> {
                        boolean committed = false;
                        for (int n = 0; n < 32; n++) if (await(runner.next()) instanceof Committed) { committed = true; break; }
                        check(committed); expect(TransitException.Kind.TURN_EXPIRED, () -> handler.escaped.stageHttp(request));
                        expect(TransitException.Kind.TURN_EXPIRED, () -> handler.escaped.releaseHttp(handler.peer, request.resource(), BigInteger.ONE));
                        expect(TransitException.Kind.TURN_EXPIRED, () -> handler.escaped.followupHttp(handler.peer, disposal, reason, request)); report(handler.result);
                    }
                    case "open" -> {
                        outcome = (Http.Outcome)Http.decodeReply(72, HexFormat.of().parseHex(cfg.get("outcome").getAsString()));
                        reader = await(runner.openHttp(outcome)); Http.Outcome selected = outcome;
                        expect(TransitException.Kind.BUSY, () -> await(runner.openHttp(selected)));
                        Http.Part first = await(reader.read()).orElseThrow(); check(first.data().size() > 0 && !first.complete()); report(Values.obj("prefix", true));
                    }
                    case "denied" -> { Http.Reader active = reader; expect(TransitException.Kind.ACCESS_DENIED, () -> await(active.read())); report(Values.obj("denied", true)); }
                    case "reopen" -> {
                        try { await(reader.read()); throw new AssertionError("Poisoned HTTP reader resumed"); }
                        catch (TransitException error) { check(error.kind() == TransitException.Kind.READ_FAILED && error.code().equals("HttpReplayFailed")); }
                        reader.close(); reader.close(); reader = await(runner.openHttp(outcome));
                        for (;;) { Optional<Http.Part> part = await(reader.read()); if (part.isEmpty()) break;
                            if (part.orElseThrow().kind() == Http.PartKind.RESPONSE_BODY) owned.writeBytes(part.orElseThrow().data().copy()); }
                        check(reader.complete()); reader.close(); report(Values.obj("complete", true, "body", HexFormat.of().formatHex(owned.toByteArray())));
                    }
                    case "close" -> {
                        runner.closeSnapshot(); if (reader != null) { Http.Reader active = reader; expect(TransitException.Kind.CLOSED, () -> await(active.read())); }
                        report(Values.obj("closed", true, "owned", HexFormat.of().formatHex(owned.toByteArray()))); return;
                    }
                    default -> throw new AssertionError("Unknown HTTP command");
                }
            }
        }
    }
    static void grpcGolden(JsonObject cfg) {
        JsonObject fixture=read(Path.of(cfg.get("grpc_fixtures").getAsString()));
        byte[] encoded=HexFormat.of().parseHex(fixture.get("outcome_ok_hex").getAsString());
        Grpc.Outcome ok=(Grpc.Outcome)Grpc.decodeReply(72,encoded);
        check(ok.diagnostic().get("code").getAsString().equals("grpc.ok_observed"));
        check(ok.phase()==Grpc.Phase.OBSERVED && ok.status().orElseThrow()==0 && ok.exchange().equals(Values.U64_MAX) && ok.reference().isPresent());
        Grpc.Outcome unknown=(Grpc.Outcome)Grpc.decodeReply(72,HexFormat.of().parseHex(fixture.get("outcome_unknown_hex").getAsString()));
        check(unknown.diagnostic().get("outcome").getAsString().equals("closed_unknown"));
        check(unknown.phase()==Grpc.Phase.CLOSED_UNKNOWN && unknown.status().isEmpty() && unknown.reference().isEmpty());
        check(Grpc.decodeReply(72,HexFormat.of().parseHex(fixture.get("rejection_hex").getAsString())) instanceof Grpc.Rejected rejected && rejected.reason()==Grpc.Rejection.DENIED);
        check(Grpc.decodeReply(72,HexFormat.of().parseHex(fixture.get("released_hex").getAsString())).equals(new Grpc.Released(new ResourceRef(72,7),Values.U64_MAX)));
        Grpc.ReplyCodec<BigInteger> codec=new Grpc.ReplyCodec<>(Codecs.U64,72);
        check(((Grpc.Application<BigInteger>)codec.decode(codec.encode(new Grpc.Application<>(Values.U64_MAX)))).value().equals(Values.U64_MAX));
        check(((Grpc.Outcome)((Grpc.Received<BigInteger>)codec.decode(encoded)).value()).status().orElseThrow()==0);
        expect(TransitException.Kind.CODEC,()->codec.encode(new Grpc.Received<>(ok)));
        try { Grpc.decodeReply(72,Arrays.copyOf(encoded,72)); throw new AssertionError("Truncated RPC accepted"); } catch(TransitException expected) { }
    }
    static final class GrpcBytes implements Codec<Bytes> {
        public String typeId() { return "test.grpc-control"; }
        public long version() { return 1; }
        public int maxEncodedBytes() { return 243; }
        public byte[] encode(Bytes value) { return value.copy(); }
        public Bytes decode(byte[] value) { return new Bytes(value); }
    }
    static final class GrpcHandler implements Handler<Grpc.Message<Bytes>> {
        final ProcessRef peer;
        final Grpc.Prepared request;
        final Key<BigInteger> correlation = new Key<>("grpc-correlation", Codecs.U64);
        final Key<BigInteger> releaseCorrelation = new Key<>("grpc-release-correlation", Codecs.U64);
        final Key<BigInteger> followupCorrelation = new Key<>("grpc-followup-correlation", Codecs.U64);
        final Grpc.Outcome disposal;
        final Grpc.Outcome wrongParent;
        Turn escaped;
        JsonObject result;
        GrpcHandler(ProcessRef peer, Grpc.Prepared request, Grpc.Outcome disposal, Grpc.Outcome wrongParent) { this.peer = peer; this.request = request; this.disposal = disposal; this.wrongParent = wrongParent; }
        @Override public void onMessage(Turn turn, Incoming<Grpc.Message<Bytes>> input) {
            escaped = turn;
            if (input instanceof Cast<Grpc.Message<Bytes>>) {
                if (input.value() instanceof Grpc.Application<Bytes> application && Arrays.equals(application.value().copy(), "followup".getBytes(java.nio.charset.StandardCharsets.US_ASCII))) {
                    expect(TransitException.Kind.HANDLER, () -> turn.retryGrpc(peer, wrongParent, request));
                    BigInteger id = turn.retryGrpc(peer, disposal, request);
                    turn.state().put(followupCorrelation, id); result = Values.obj("followup", false);
                } else if (input.value() instanceof Grpc.Application<Bytes> application && Arrays.equals(application.value().copy(), "dispose".getBytes(java.nio.charset.StandardCharsets.US_ASCII))) {
                    expect(TransitException.Kind.HANDLER, () -> turn.releaseGrpc(peer, new ResourceRef(73, disposal.resource().resource()), disposal.exchange()));
                    BigInteger id = turn.releaseGrpc(peer, disposal.resource(), disposal.exchange());
                    turn.state().put(releaseCorrelation, id); result = Values.obj("released", false);
                } else if (turn.state().find(correlation).isPresent()) result = Values.obj("called", true);
                else if (turn.stageGrpc(request)) { BigInteger id = turn.callGrpc(peer, request); turn.state().put(correlation, id); result = Values.obj("called", true); }
                else result = Values.obj("called", false);
            } else {
                check(input instanceof Reply<Grpc.Message<Bytes>>);
                if (((Grpc.Received<Bytes>)input.value()).value() instanceof Grpc.Rejected rejected) {
                    BigInteger id = turn.state().require(followupCorrelation);
                    turn.requireReply((Reply<?>)input, peer, id); check(rejected.reason() == Grpc.Rejection.DENIED);
                    turn.state().put(new Key<>("grpc-followup-denied", Codecs.U64), id); result = Values.obj("followup", true); return;
                }
                if (((Grpc.Received<Bytes>)input.value()).value() instanceof Grpc.Released released) {
                    turn.requireReply((Reply<?>)input, peer, turn.state().require(releaseCorrelation));
                    check(released.resource().equals(disposal.resource()) && released.exchange().equals(disposal.exchange()));
                    turn.state().put(new Key<>("grpc-disposed", Codecs.U64), released.exchange()); result = Values.obj("released", true); return;
                }
                turn.requireReply((Reply<?>)input, peer, turn.state().require(correlation));
                Grpc.Outcome outcome = (Grpc.Outcome)((Grpc.Received<Bytes>)input.value()).value();
                check(outcome.phase() == Grpc.Phase.OBSERVED && outcome.status().orElseThrow() == 0);
                turn.state().put(new Key<>("grpc-status", Codecs.U64), BigInteger.ZERO); result = Values.obj("observed", true);
            }
        }
    }
    static void grpc(String mode, JsonObject cfg) throws IOException {
        byte[] body = HexFormat.of().parseHex(cfg.get("body").getAsString());
        Grpc.Method method = Grpc.method(HexFormat.of().parseHex(cfg.get("descriptor").getAsString()), "/test.Peer/Bidi");
        check(method.shape() == Grpc.Shape.BIDI);
        Bytes message = new Bytes(body);
        Grpc.Prepared request = Grpc.prepare(new ResourceRef(72, cfg.get("resource").getAsLong()), Values.U64_MAX,
            new Grpc.Request(method, List.of(
                new Grpc.Metadata("x-tag", new Grpc.Literal(new Bytes(new byte[]{'o','n','e'}))),
                new Grpc.Metadata("x-tag", new Grpc.Literal(new Bytes(new byte[]{'t','w','o'}))),
                new Grpc.Metadata("x-data-bin", new Grpc.Literal(new Bytes(new byte[]{0,(byte)255}))),
                new Grpc.Metadata("authorization", new Grpc.SecretRef("api", BigInteger.valueOf(7))))),
            List.of(message, new Bytes(new byte[0])), new Grpc.Options(BigInteger.valueOf(7), cfg.get("deadline").getAsLong(), 1));
        byte[] original = request.batch().copy(); body[0] ^= 127; byte[] copy = request.batch().copy(); copy[0] ^= 1;
        check(Arrays.equals(original, request.batch().copy()) && request.batch().size() == message.size() + 16);
        ServiceConfig config = new ServiceConfig(new ClientConfig(URI.create(cfg.get("url").getAsString()), ClientConfig.Profile.NATIVE_V1),
            new Activation(new ProcessRef(72, cfg.get("pid").getAsLong()), cfg.get("generation").getAsLong(),
                new Credential(72, cfg.get("principal").getAsLong(), Path.of(cfg.get("seed_file").getAsString()))));
        Grpc.Outcome disposal = cfg.has("outcome") ? (Grpc.Outcome)Grpc.decodeReply(72, HexFormat.of().parseHex(cfg.get("outcome").getAsString())) : null;
        Grpc.Outcome wrongParent = cfg.has("outcome") ? (Grpc.Outcome)Grpc.decodeReply(73, HexFormat.of().parseHex(cfg.get("outcome").getAsString())) : null;
        GrpcHandler handler = new GrpcHandler(new ProcessRef(72, cfg.get("peer").getAsLong()), request, disposal, wrongParent);
        ByteArrayOutputStream owned = new ByteArrayOutputStream(); Grpc.Reader reader = null; Grpc.Outcome outcome = null;
        try (Runner<Grpc.Message<Bytes>> runner = Runner.open(config, handler, new Grpc.ReplyCodec<>(new GrpcBytes(), 72), FailurePolicy.STOP, new Recovery.FreshOwnership())) {
            if (mode.equals("grpc-async")) {
                Grpc.Reader active = await(runner.openGrpc((Grpc.Outcome)Grpc.decodeReply(72, HexFormat.of().parseHex(cfg.get("outcome").getAsString()))));
                Grpc.Part first = await(active.read()).orElseThrow(); check(first.data().size() > 0 && !first.complete());
                Files.writeString(Path.of(cfg.get("ready").getAsString()), ""); waitFile(Path.of(cfg.get("continue").getAsString()));
                CompletableFuture<Optional<Grpc.Part>> pending = active.read(); waitFile(Path.of(cfg.get("accepted").getAsString()));
                expect(TransitException.Kind.BUSY, () -> await(active.read())); check(pending.cancel(true));
                runner.stop(); CompletableFuture<Shutdown> closing = runner.closeAsync(); int beats = 0;
                while (!closing.isDone()) { beats++; sleep(10); } await(closing); check(beats > 5 && first.data().size() > 0);
                expect(TransitException.Kind.CLOSED, () -> await(active.read())); report(Values.obj("joined", true)); return;
            }
            BufferedReader input = new BufferedReader(new InputStreamReader(System.in, java.nio.charset.StandardCharsets.UTF_8));
            for (String line; (line = input.readLine()) != null;) {
                switch (line) {
                    case "step" -> {
                        boolean committed = false;
                        for (int n = 0; n < 32; n++) if (await(runner.next()) instanceof Committed) { committed = true; break; }
                        check(committed); expect(TransitException.Kind.TURN_EXPIRED, () -> handler.escaped.stageGrpc(request));
                        expect(TransitException.Kind.TURN_EXPIRED, () -> handler.escaped.releaseGrpc(handler.peer, request.resource(), BigInteger.ONE));
                        expect(TransitException.Kind.TURN_EXPIRED, () -> handler.escaped.retryGrpc(handler.peer, disposal, request)); report(handler.result);
                    }
                    case "open" -> {
                        outcome = (Grpc.Outcome)Grpc.decodeReply(72, HexFormat.of().parseHex(cfg.get("outcome").getAsString()));
                        reader = await(runner.openGrpc(outcome)); Grpc.Outcome selected = outcome;
                        expect(TransitException.Kind.BUSY, () -> await(runner.openGrpc(selected)));
                        Grpc.Part first = await(reader.read()).orElseThrow(); check(first.data().size() > 0 && !first.complete()); report(Values.obj("prefix", true));
                    }
                    case "denied" -> { Grpc.Reader active = reader; expect(TransitException.Kind.ACCESS_DENIED, () -> await(active.read())); report(Values.obj("denied", true)); }
                    case "reopen" -> {
                        try { await(reader.read()); throw new AssertionError("Poisoned RPC reader resumed"); }
                        catch (TransitException error) { check(error.kind() == TransitException.Kind.READ_FAILED && error.code().equals("GrpcReplayFailed")); }
                        reader.close(); reader.close(); reader = await(runner.openGrpc(outcome));
                        for (;;) { Optional<Grpc.Part> part = await(reader.read()); if (part.isEmpty()) break;
                            if (part.orElseThrow().kind() == Grpc.PartKind.RESPONSE_BODY) owned.writeBytes(part.orElseThrow().data().copy()); }
                        check(reader.complete()); reader.close(); report(Values.obj("complete", true, "body", HexFormat.of().formatHex(owned.toByteArray())));
                    }
                    case "close" -> {
                        runner.closeSnapshot(); if (reader != null) { Grpc.Reader active = reader; expect(TransitException.Kind.CLOSED, () -> await(active.read())); }
                        report(Values.obj("closed", true, "owned", HexFormat.of().formatHex(owned.toByteArray()))); return;
                    }
                    default -> throw new AssertionError("Unknown RPC command");
                }
            }
        }
    }
    static <T> void execute(String mode, JsonObject cfg, Handler<T> handler, Codec<T> codec) throws Exception {
        long realm = cfg.get("realm").getAsLong();
        ServiceConfig config = new ServiceConfig(new ClientConfig(URI.create(cfg.get("url").getAsString()), ClientConfig.Profile.NATIVE_V1),
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
                    if (line.equals("ready")) { report(Values.obj("ready", true)); continue; }
                    if (line.equals("close")) {
                        runner.closeSnapshot();
                        if (handler instanceof QueryProof query) query.saveOwned();
                        if (handler instanceof TableProof table) table.expired();
                        report(Values.obj("closed", true)); break;
                    }
                    check(line.equals("one") || line.equals("reconcile")); Event event = null;
                    try {
                        for (int count = 0; count < 32; count++) { event = await(line.equals("reconcile") && count == 0 ? runner.reconcile() : runner.next()); if (!(event instanceof Progress)) break; }
                    } catch (TransitException error) {
                        if (error.status() != 7) throw error;
                        report(Values.obj("event", "ReadUnavailable", "code", error.code())); continue;
                    }
                    if (event instanceof NeedsRecovery paused) check(Arrays.equals(paused.mutation().export(), Files.readAllBytes(store.pending)));
                    report(event instanceof NeedsRecovery paused
                        ? Values.obj("event", "NeedsRecovery", "phase", paused.phase(), "code", paused.error().code())
                        : Values.obj("event", Objects.requireNonNull(event).getClass().getSimpleName()));
                }
            }
        }
    }
    static final class DocumentHandler implements Handler<Bytes> {
        final List<Document.Prepared> changes; Document.Phase phase; Document.Owner escaped;
        DocumentHandler(List<Document.Prepared> changes) { this.changes=List.copyOf(changes); }
        @Override public void initialize(Turn turn) { turn.document(Values.U64_MAX).create(1); }
        @Override public void onMessage(Turn turn,Incoming<Bytes> input) {
            Document.Owner owner=turn.document(Values.U64_MAX); escaped=owner; phase=null;
            String command=new String(((Cast<Bytes>)input).value().copy(),java.nio.charset.StandardCharsets.UTF_8);
            switch(command) {
                case "initialize" -> {}
                case "checkpoint" -> phase=owner.checkpoint(BigInteger.valueOf(90)).phase();
                case "window" -> owner.mergeWindow(BigInteger.TWO);
                case "retire" -> owner.retire();
                case "0", "1" -> { int index=Integer.parseInt(command); phase=owner.stage(BigInteger.valueOf(index+1),changes.get(index),256).phase(); }
                default -> throw new AssertionError("Unknown Document tick");
            }
        }
    }
    static void document(String mode,JsonObject cfg) throws IOException {
        BigInteger max=Values.U64_MAX; ResourceRef resource=new ResourceRef(72,cfg.get("resource").getAsLong());
        if(mode.equals("document-codecs")) {
            JsonObject fixtures=read(Path.of(cfg.get("document_fixtures").getAsString()));
            for(JsonElement entry:fixtures.getAsJsonArray("changes")) {
                byte[] data=HexFormat.of().parseHex(entry.getAsJsonObject().get("wire_hex").getAsString());
                check(Arrays.equals(Document.prepare(Document.decode(data)).bytes().copy(),data));
                for(int size:new int[]{0,1,data.length-1}) { boolean rejected=false; try { Document.decode(Arrays.copyOf(data,size)); } catch(TransitException | IllegalArgumentException expected) { rejected=true; } check(rejected); }
            }
            byte[] encoded=HexFormat.of().parseHex(fixtures.get("reference_hex").getAsString());
            Document.Reference reference=Document.Reference.decode(72,encoded); check(reference.document().equals(max) && reference.revision().equals(max) && Arrays.equals(reference.bytes().copy(),encoded));
            var root=Document.Dot.ROOT;
            Document.Change bootstrap=new Document.Change(max,BigInteger.ONE,1,max,BigInteger.ZERO,BigInteger.ONE,List.of(
                new Document.Assign(root,"value",List.of(),new Document.Signed(Long.MIN_VALUE)),
                new Document.Assign(root,"body",List.of(),Document.Container.TEXT),
                new Document.Insert(new Document.Dot(BigInteger.TWO,max),root,new Document.CharacterValue(0x1f642))));
            Document.Prepared prepared=Document.prepare(bootstrap); byte[] copy=prepared.bytes().copy(); copy[0]^=127;
            check(HexFormat.of().formatHex(prepared.bytes().copy()).equals(cfg.getAsJsonArray("changes").get(0).getAsString()));
            boolean rejected=false; try { new Document.StringValue("\ud800"); } catch(IllegalArgumentException expected) { rejected=true; } check(rejected);
            rejected=false; try { new Document.CharacterValue(0xdfff); } catch(IllegalArgumentException expected) { rejected=true; } check(rejected);
            report(Values.obj("codecs",true)); return;
        }
        List<Document.Prepared> changes=cfg.getAsJsonArray("changes").asList().stream().map(v -> Document.prepare(Document.decode(HexFormat.of().parseHex(v.getAsString())))).toList();
        ServiceConfig config=new ServiceConfig(new ClientConfig(URI.create(cfg.get("url").getAsString()),ClientConfig.Profile.NATIVE_V1),new Activation(new ProcessRef(72,cfg.get("pid").getAsLong()),cfg.get("generation").getAsLong(),new Credential(72,cfg.get("principal").getAsLong(),Path.of(cfg.get("seed_file").getAsString()))));
        DocumentHandler handler=new DocumentHandler(changes); Document.Reference saved=null;
        try(Runner<Bytes> runner=Runner.open(config,handler,new GrpcBytes(),FailurePolicy.STOP,new Recovery.FreshOwnership())) {
            Document.Reader reader=runner.documents(); BufferedReader input=new BufferedReader(new InputStreamReader(System.in));
            for(String command;(command=input.readLine())!=null;) {
                switch(command) {
                    case "one" -> {
                        boolean committed=false;
                        for(int i=0;i<12;i++) { Event event=await(runner.next()); if(event instanceof Committed) { committed=true; break; } check(event instanceof Progress); }
                        check(committed); expect(TransitException.Kind.TURN_EXPIRED,() -> handler.escaped.mergeWindow(BigInteger.ZERO));
                        report(Values.obj("event","committed","phase",handler.phase==null?null:handler.phase.name().toLowerCase(Locale.ROOT)));
                    }
                    case "read" -> {
                        Document.Description description=await(reader.describe(resource,max)); Document.Reference ref=description.reference();
                        check(description.floor().signum()==0 && description.mergeWindow().signum()==0);
                        Document.PathValue value=await(reader.path(ref,List.of("value"))); Document.Page page=await(reader.sequence(ref,new Document.Dot(BigInteger.TWO,max),Optional.empty()));
                        check(page.next().isEmpty()); StringBuilder text=new StringBuilder(); for(Document.Item item:page.items()) text.appendCodePoint(((Document.CharacterValue)item.field().assignments().getFirst().value()).codePoint());
                        boolean initial=ref.revision().equals(BigInteger.TWO); check(text.toString().equals(initial?"🙂":"🙂́"));
                        check(((Document.Signed)value.field().assignments().getFirst().value()).value()==Long.MIN_VALUE);
                        check(await(reader.path(ref,List.of("missing"))).field().status()==Document.Status.MISSING);
                        check(Document.prepare(await(reader.acceptedChange(ref))).bytes().equals(changes.get(ref.revision().intValueExact()-2).bytes()));
                        check(value.field().status()==(initial?Document.Status.SCALAR:Document.Status.CONFLICT)); if(saved==null) saved=ref;
                        report(Values.obj("revision",ref.revision().toString(),"items",page.items().size(),"status",initial?"scalar":"conflict"));
                    }
                    case "old" -> { check(await(reader.path(saved,List.of("value"))).field().status()==Document.Status.SCALAR); report(Values.obj("retained",true)); }
                    case "denied" -> { Document.Reference ref=saved; expect(TransitException.Kind.ACCESS_DENIED,() -> await(reader.path(ref,List.of("value")))); report(Values.obj("denied",true)); }
                    case "resynchronize" -> { var result=await(reader.resynchronize(resource,max,max)); check(result.reference().revision().equals(BigInteger.valueOf(3))); report(Values.obj("previous",result.previousCounter().toString(),"clock",result.clock().toString())); }
                    case "retired" -> { check(await(reader.describe(resource,max)).retired()); try { await(reader.path(saved,List.of("value"))); throw new AssertionError("Retired read accepted"); } catch(TransitException error) { check(error.code().equals("DocumentRetired")); } report(Values.obj("retired",true)); }
                    case "async-close" -> {
                        Runner<Bytes> other=Runner.open(config,new DocumentHandler(changes),new GrpcBytes(),FailurePolicy.STOP,new Recovery.FreshOwnership());
                        Document.Reader active=other.documents(); CompletableFuture<Document.Description> pending=active.describe(resource,max); pending.cancel(true); other.close();
                        expect(TransitException.Kind.CLOSED,() -> await(active.describe(resource,max))); report(Values.obj("joined",true));
                    }
                    case "close" -> { runner.closeSnapshot(); expect(TransitException.Kind.CLOSED,() -> await(reader.describe(resource,max))); report(Values.obj("closed",true)); return; }
                    default -> throw new AssertionError("Unknown Document command");
                }
            }
        }
    }

    public static void main(String[] args) throws Exception {
        String mode = args[0]; Path path = Path.of(args[1]); JsonObject cfg = read(path);
        check(Path.of(Runner.class.getProtectionDomain().getCodeSource().getLocation().toURI()).startsWith(path.getParent()));
        check(cfg.get("profile").getAsString().equals("native_v1"));
        if (mode.startsWith("document-")) { document(mode,cfg); return; }
        if (mode.equals("grpc-golden")) { grpcGolden(cfg); return; }
        if (mode.startsWith("grpc-")) { grpc(mode, cfg); return; }
        if (mode.startsWith("http-")) { http(mode, cfg); return; }
        if (mode.equals("codecs")) { codecs(cfg); return; }
        if (mode.equals("recover")) {
            try (Client client = Client.open(new ClientConfig(URI.create(cfg.get("url").getAsString()), ClientConfig.Profile.NATIVE_V1));
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
