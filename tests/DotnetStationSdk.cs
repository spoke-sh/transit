using System.Buffers.Binary;
using System.Text.Json.Nodes;
using Transit.Client;
using Transit.Station.Sdk;
using Transit.Sdk.Examples;
using SdkClient = Transit.Client.Client;
using SdkStation = Transit.Station.Sdk.Station;

[System.Runtime.Versioning.SupportedOSPlatform("linux")]
static class Proof
{
    static void Check(bool value) { if (!value) throw new Exception(".NET Station proof failed"); }
    static void Expect(ErrorKind kind, Action action) {
        try { action(); } catch (TransitException error) { if (error.Kind != kind) throw new Exception($"Expected {kind}, got {error.Kind}, {error.Code}, {error.Phase}"); return; }
        throw new Exception($"Expected {kind}");
    }
    static JsonObject Read(string path) => JsonNode.Parse(File.ReadAllBytes(path))!.AsObject();
    static void Write(string path, JsonObject value) => File.WriteAllText(path, value.ToJsonString());
    static void Report(JsonObject value) { Console.WriteLine(value.ToJsonString()); Console.Out.Flush(); }
    static ulong Number(JsonObject value, string key) => value[key]!.GetValue<ulong>();
    static string Text(JsonObject value, string key) => value[key]!.GetValue<string>();
    static void WaitFile(string path) { var until = DateTime.UtcNow.AddSeconds(30); while (!File.Exists(path)) { Check(DateTime.UtcNow < until); Thread.Sleep(10); } }
    static void OtherThread(Action action) {
        Exception? failed = null; var thread = new Thread(() => { try { action(); } catch (Exception error) { failed = error; } });
        thread.Start(); thread.Join(); if (failed is not null) throw failed;
    }
    sealed class Reentrant(Turn turn) : ICodec<ulong> {
        public string TypeId => Codecs.U64.TypeId; public uint Version => 1; public int MaxEncodedBytes => 12;
        public byte[] Encode(ulong value) => throw new Exception("unused");
        public ulong Decode(byte[] bytes) { Expect(ErrorKind.Busy, () => _ = turn.Budgets()); return Codecs.U64.Decode(bytes); }
    }
    sealed class CounterProof(string mode) : Counter {
        public int Initialized, Handled;
        public State? Escaped;
        public override void Initialize(Turn turn) { Initialized++; Check(turn.Budgets().Mutations == 3); base.Initialize(turn); }
        public override void OnMessage(Turn turn, Incoming<ICounterMessage> input) {
            Handled++; Escaped = turn.State;
            OtherThread(() => Expect(ErrorKind.Busy, () => Escaped.Require(StateKeys.Total)));
            if (mode.StartsWith("handler-", StringComparison.Ordinal)) { turn.State.Put(StateKeys.Total, 73UL); throw new Exception("Injected handler failure"); }
            if (mode == "poison") { Expect(ErrorKind.ReadFailed, () => turn.State.Require(StateKeys.Total)); return; }
            turn.State.Require(new Key<ulong>("total", new Reentrant(turn)));
            base.OnMessage(turn, input);
        }
    }
    sealed class InvalidHandler : IHandler<ICounterMessage> {
        public async void OnMessage(Turn turn, Incoming<ICounterMessage> input) { await Task.Yield(); turn.State.Put(StateKeys.Total, 73UL); }
    }
    sealed class InvalidStore : IRecoveryStore {
        public async void BeforeDispatch(FrozenMutation mutation) { await Task.Yield(); }
        public void Confirmed(OperationIdentity identity, MutationReceipt receipt) { }
    }
    sealed class TableProof(ProcessRef peer, string output) : TableService(peer) {
        Table<long?>? escaped; Source? source;
        public override void OnMessage(Turn turn, Incoming<IQueryMessage> input) {
            string saved = Path.Combine(output, "version.json");
            if (input is Cast<IQueryMessage> { Value: Rows }) {
                Table<long?> table = turn.Table(StateKeys.Table); escaped = table;
                Cursor? cursor = null; List<TableRow<long?>> rows = []; int pages = 0;
                do { var page = table.Page(cursor); Check(page.Entries.Count <= 8 && page.Basis == table.Basis); rows.AddRange(page.Entries); pages++; cursor = page.Cursor; } while (cursor is not null);
                Check(rows.Count == 41 && pages == 6 && rows[0].Key == long.MinValue && rows[0].Value is null);
                var version = turn.Retain(); Write(saved, new() { ["pid"] = version.Pid, ["input"] = version.Input, ["index"] = version.Index });
                table.Update(new(long.MinValue, 17));
            } else if (input.Value is Transit.Sdk.Examples.Initialize && File.Exists(saved)) {
                var record = Read(saved); var version = new ReadVersion(Number(record, "pid"), Number(record, "input"), checked((byte)Number(record, "index")));
                Check(turn.Table(StateKeys.Table).Get(long.MinValue)!.Value == 17);
                source = turn.OpenVersion(version); Check(source.Table(StateKeys.Table).Get(long.MinValue)!.Value is null);
                Check(source.Table(StateKeys.Table).Page().Entries.Count == 8 && source.State.Page().Entries.Count <= 8); turn.Release(version);
            } else base.OnMessage(turn, input);
        }
        public void Expired() { if (escaped is not null) Expect(ErrorKind.TurnExpired, () => escaped.Get(0)); if (source is not null) Expect(ErrorKind.TurnExpired, () => _ = source.State); }
    }
    sealed class QueryProof : QueryRequester {
        readonly string output; readonly List<IpcSegment> owned; ResultReader? escaped;
        public QueryProof(ProcessRef peer, string output) : this(peer, output, []) { }
        QueryProof(ProcessRef peer, string output, List<IpcSegment> owned) : base(peer, owned.Add) { this.output = output; this.owned = owned; }
        public override void OnMessage(Turn turn, Incoming<IQueryMessage> input) {
            string saved = Path.Combine(output, "manifest.json");
            if (File.Exists(saved)) { var reader = turn.Result(ulong.Parse(Text(Read(saved), "correlation"))); Check(reader.Manifest().Rows == 41);
                File.WriteAllText(Path.Combine(output, "ready"), ""); WaitFile(Path.Combine(output, "continue")); reader.Segment(0);
            } else base.OnMessage(turn, input);
        }
        public override void OnResult(Turn turn, ResultComplete complete) {
            base.OnResult(turn, complete); escaped = turn.Result(complete.Correlation); var manifest = escaped.Manifest();
            Write(Path.Combine(output, "manifest.json"), new() { ["rows"] = manifest.Rows, ["segments"] = manifest.Segments, ["correlation"] = manifest.Correlation.ToString(),
                ["source"] = manifest.Source.Pid, ["destination"] = manifest.Destination.Pid, ["resource"] = manifest.Basis.Resource.Resource,
                ["revision"] = manifest.Basis.Revision, ["bytes"] = manifest.ByteCount });
        }
        public void SaveOwned() { if (escaped is not null) Expect(ErrorKind.TurnExpired, () => escaped.Manifest());
            foreach (var segment in owned) { byte[] original = segment.Ipc(); segment.Ipc()[0] ^= 1; Check(original.AsSpan().SequenceEqual(segment.Ipc())); File.WriteAllBytes(Path.Combine(output, segment.Ordinal + ".arrow"), original); }
        }
    }
    sealed class Store(string mode, string pending) : IRecoveryStore {
        public Action? Reentry; public string Pending => pending;
        public readonly HashSet<Purpose> BeforeFailed = [], ConfirmFailed = [];
        public readonly Dictionary<OperationIdentity, byte[]> Saved = [];
        public readonly Dictionary<OperationIdentity, MutationReceipt> Confirmations = [];
        FrozenMutation? current;
        public void BeforeDispatch(FrozenMutation mutation) {
            current = mutation;
            if (mode == "gates") { Reentry!(); if (BeforeFailed.Add(mutation.Purpose)) throw new Exception("Persistence failure"); }
            byte[] bytes = mutation.Export(); if (Saved.TryGetValue(mutation.Identity, out var old)) Check(old.AsSpan().SequenceEqual(bytes)); Saved[mutation.Identity] = bytes;
            using var file = new FileStream(pending, new FileStreamOptions { Mode = FileMode.Create, Access = FileAccess.Write, UnixCreateMode = UnixFileMode.UserRead | UnixFileMode.UserWrite });
            file.Write(bytes); file.Flush(flushToDisk: true);
            // This harness's file is pre-created by the schedule, so no new directory entry is admitted here.
        }
        public void Confirmed(OperationIdentity identity, MutationReceipt receipt) {
            Check(Saved.ContainsKey(identity) && receipt.Position > 0);
            if (mode == "gates" && ConfirmFailed.Add(current!.Purpose)) throw new Exception("Confirmation failure");
            Confirmations[identity] = receipt;
        }
    }
    static void Roundtrip<T>(ICodec<T> codec, byte[] bytes) where T : notnull => Check(codec.Encode(codec.Decode(bytes)).AsSpan().SequenceEqual(bytes));
    static void BoundaryProof() {
        // Exercise the installed generated contract, including distinctions that
        // convenience Find/Page APIs must never collapse to absence/completion.
        using var resource = typeof(Runner<>).Assembly.GetManifestResourceStream("transit.station.contract.json")!;
        var schemas = JsonNode.Parse(resource)!["schemas"]!.AsObject();
        var valid = typeof(SdkClient).Assembly.GetType("Transit.Client.Internal.Schema")!.GetMethod("Valid", System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Static)!;
        bool Accept(JsonNode schema, string json) => (bool)valid.Invoke(null, [schema, JsonNode.Parse(json)])!;
        var result = schemas["GrowingResult"]!;
        Check(Accept(result, "{\"value\":null}") && !Accept(result, "{}") && !Accept(result, "{\"value\":0}"));
        var page = result["oneOf"]!.AsArray().Single(branch => branch!["properties"]!["page"] is not null)!["properties"]!["page"]!;
        Check(Accept(page, "{\"entries\":[null,null,null,null,null,null,null,null],\"next\":null}"));
        Check(!Accept(page, "{\"entries\":[null,null,null,null,null,null,null,null]}") && !Accept(page, "{\"entries\":[null,null,null,null,null,null,null,null],\"next\":1}"));
        var number = schemas["GrowingEvent"]!["properties"]!["pid"]!;
        Check(Accept(number, "1") && !Accept(number, "1.00000000000000000000000000001") && !Accept(number, "1e999999999") && !Accept(number, "1e-999999999"));
    }
    static async Task CodecsProof(JsonObject cfg) {
        BoundaryProof();
        var counter = new Codecs.CounterCodec(typeof(Add), typeof(Read), typeof(Start), typeof(Total));
        var query = new Codecs.QueryCodec(typeof(Transit.Sdk.Examples.Initialize), typeof(Insert), typeof(Rows), typeof(Start));
        var fixtures = Read(Text(cfg, "fixtures"));
        foreach (var item in fixtures["valid"]!.AsArray()) {
            var fixture = item!.AsObject(); byte[] bytes = Convert.FromHexString(Text(fixture, "hex"));
            switch (Text(fixture, "codec")) {
                case "u64": Roundtrip(Codecs.U64, bytes); Check(Codecs.U64.Decode(bytes) == ulong.Parse(Text(fixture, "value"))); break;
                case "counter": Roundtrip<ICounterMessage>(counter, bytes); var decoded = counter.Decode(bytes); Check(decoded.GetType().Name == Text(fixture, "variant"));
                    if (decoded is Add add) Check(add.Value == ulong.Parse(Text(fixture, "value"))); if (decoded is Total total) Check(total.Value == ulong.Parse(Text(fixture, "value"))); break;
                case "query": Roundtrip<IQueryMessage>(query, bytes); var row = query.Decode(bytes); Check(row.GetType().Name == Text(fixture, "variant"));
                    if (row is Insert insert) { Check(insert.Key == long.Parse(Text(fixture, "key"))); Check(insert.Value == (fixture["value"] is null ? null : long.Parse(Text(fixture, "value")))); } break;
                default: throw new Exception("Unknown fixture");
            }
        }
        foreach (var item in fixtures["invalid"]!.AsArray()) {
            var fixture = item!.AsObject(); byte[] bytes = Convert.FromHexString(Text(fixture, "hex")); bool rejected = false;
            try { switch (Text(fixture, "codec")) { case "u64": Codecs.U64.Decode(bytes); break; case "counter": counter.Decode(bytes); break; case "query": query.Decode(bytes); break; default: throw new Exception("Unknown fixture"); } }
            catch (ArgumentException) { rejected = true; } Check(rejected);
        }
        var value = new Add((1UL << 53) + 1); byte[] expected = new byte[26]; "STN1"u8.CopyTo(expected); expected[4] = 1; BinaryPrimitives.WriteUInt64LittleEndian(expected.AsSpan(5), 0); Codecs.Counter.Encode(value).CopyTo(expected, 13);
        byte[] frame = await SdkStation.EncodeCastAsync<ICounterMessage>(value, Codecs.Counter); Check(expected.AsSpan().SequenceEqual(frame));
        Expect(ErrorKind.IncompatibleNative, () => SdkStation.EncodeCastAsync<ICounterMessage>(value, Codecs.Counter, Path.Combine(Path.GetDirectoryName(Text(cfg, "fixtures"))!, "bad-station-version")).GetAwaiter().GetResult());
        Check(counter.TypeId == "transit.examples.counter" && query.TypeId == "transit.examples.query" && Codecs.U64.TypeId == "transit.examples.u64");
    }
    static async Task Execute<T>(string mode, JsonObject cfg, IHandler<T> handler, ICodec<T> codec) where T : notnull {
        ulong realm = Number(cfg, "realm");
        var config = new ServiceConfig(new ClientConfig(new Uri(Text(cfg, "url")), Profile.GrowingV3),
            new Activation(new ProcessRef(realm, Number(cfg, "pid")), Number(cfg, "generation"), new Credential(realm, Number(cfg, "principal"), Text(cfg, "seed_file"))), "data", cfg["query_results"]!.GetValue<bool>());
        var store = new Store(mode, Text(cfg, "pending")); FailurePolicy failure = mode.EndsWith("-block", StringComparison.Ordinal) ? FailurePolicy.BlockInput : FailurePolicy.Stop;
        Recovery recovery = new Recovery.PersistBeforeDispatch(store);
        if (mode == "denied") { Expect(ErrorKind.AccessDenied, () => Runner<T>.OpenAsync(config, handler, codec, failure, recovery).GetAwaiter().GetResult()); return; }
        if (mode == "async-handler") {
            Expect(ErrorKind.Handler, () => Runner<ICounterMessage>.OpenAsync(config, new InvalidHandler(), Codecs.Counter, failure, recovery).GetAwaiter().GetResult());
            Expect(ErrorKind.Handler, () => Runner<T>.OpenAsync(config, handler, codec, failure, new Recovery.PersistBeforeDispatch(new InvalidStore())).GetAwaiter().GetResult()); return;
        }
        await using var runner = await Runner<T>.OpenAsync(config, handler, codec, failure, recovery);
        store.Reentry = () => { Expect(ErrorKind.Busy, () => runner.NextAsync().GetAwaiter().GetResult()); Expect(ErrorKind.Busy, () => runner.CloseSnapshot()); Expect(ErrorKind.Busy, () => runner.CloseAsync()); };
        if (mode == "gates") {
            HashSet<string> phases = []; bool done = false;
            for (int count = 0; count < 40; count++) { var ev = await runner.NextAsync();
                if (ev is NeedsRecovery paused) { phases.Add(paused.Phase); if (paused.Phase == "confirm") Check(paused.Receipt is not null); Check(ReferenceEquals(await runner.NextAsync(), ev)); ev = await runner.ReconcileAsync(); }
                if (ev is Committed) { done = true; break; }
            }
            Check(done && phases.SetEquals(["persist", "confirm"]) && store.Confirmations.Count == 3);
            var counter = (CounterProof)(object)handler; Check(counter.Initialized == 1 && counter.Handled == 1); Expect(ErrorKind.TurnExpired, () => counter.Escaped!.Require(StateKeys.Total));
            Report(new() { ["gates"] = new JsonArray(store.ConfirmFailed.Select(p => p.ToString().ToLowerInvariant()).OrderBy(p => p).Select(p => (JsonNode?)JsonValue.Create(p)).ToArray()), ["handled"] = counter.Handled, ["dispatches"] = store.Saved.Count });
        } else if (mode == "async") {
            Check(await runner.NextAsync() is not Committed); using var cancellation = new CancellationTokenSource();
            async Task Advance() { for (;;) { if (await runner.NextAsync(cancellation.Token) is Committed) throw new Exception("Expected cancellation"); } }
            Task waiting = Advance(); await Task.Run(() => WaitFile(Path.Combine(Text(cfg, "output"), "accepted")));
            Expect(ErrorKind.Busy, () => runner.NextAsync().GetAwaiter().GetResult()); cancellation.Cancel();
            bool cancelled = false; try { await waiting; } catch (OperationCanceledException) { cancelled = true; } Check(cancelled);
            runner.Stop(); Task<RunnerShutdown> closing = runner.CloseAsync(); int beats = 0; while (!closing.IsCompleted) { beats++; await Task.Delay(10); }
            var evidence = await closing; Check(beats > 5 && evidence.Pending is null && evidence.LastEvent is Committed && ((CounterProof)(object)handler).Handled == 1);
            Report(new() { ["committed"] = true, ["beats"] = beats });
        } else if (mode.StartsWith("decode-", StringComparison.Ordinal) || mode.StartsWith("handler-", StringComparison.Ordinal)) {
            bool stopped = false;
            for (int count = 0; count < 8; count++) { try { if (await runner.NextAsync() is Blocked blocked) { Check(mode.EndsWith("-block", StringComparison.Ordinal) && blocked.Receipt is not null); stopped = true; break; } }
                catch (TransitException error) { Check(!mode.EndsWith("-block", StringComparison.Ordinal)); Check(error.Kind == (mode.StartsWith("decode-", StringComparison.Ordinal) ? ErrorKind.Codec : ErrorKind.Handler)); stopped = true; break; } }
            Check(stopped);
        } else if (new[] { "stale", "expired", "revoked-result", "poison" }.Contains(mode)) {
            var expected = mode switch { "stale" => ErrorKind.StaleOwnership, "expired" => ErrorKind.ProcessRetired, "revoked-result" => ErrorKind.AccessDenied, _ => ErrorKind.ReadFailed };
            Expect(expected, () => { for (int count = 0; count < 8; count++) runner.NextAsync().GetAwaiter().GetResult(); }); Report(new() { ["denied"] = true });
        } else {
            for (string? line; (line = Console.ReadLine()) is not null;) {
                if (line == "close") { await runner.CloseAsync(); if (handler is QueryProof query) query.SaveOwned(); if (handler is TableProof table) table.Expired(); Report(new() { ["closed"] = true }); break; }
                Check(line == "one"); RunnerEvent? ev = null; for (int count = 0; count < 32; count++) { ev = await runner.NextAsync(); if (ev is not Progress) break; }
                if (ev is NeedsRecovery paused) Check(paused.Mutation.Export().AsSpan().SequenceEqual(File.ReadAllBytes(store.Pending)));
                Report(new() { ["event"] = ev!.GetType().Name });
            }
        }
    }
    public static async Task Main(string[] args) {
        string mode = args[0], path = args[1]; var cfg = Read(path);
        Check(typeof(Runner<>).Assembly.Location.StartsWith(Path.GetDirectoryName(path)!, StringComparison.Ordinal)); Check(Text(cfg, "profile") == "growing_v3");
        if (mode == "codecs") { await CodecsProof(cfg); return; }
        if (mode == "recover") { await using var client = await SdkClient.OpenAsync(new ClientConfig(new Uri(Text(cfg, "url")), Profile.GrowingV3));
            using var pending = await client.RecoverMutationAsync(File.ReadAllBytes(Text(cfg, "pending"))); var result = await client.DispatchMutationAsync(pending); Check(result is Confirmed);
            Report(new() { ["receipt"] = ((Confirmed)result).Receipt.Position }); return; }
        var peer = new ProcessRef(Number(cfg, "realm"), Number(cfg, "peer")); string output = Text(cfg, "output");
        switch (Text(cfg, "role")) {
            case "service": await Execute(mode, cfg, new CounterProof(mode), Codecs.Counter); break;
            case "requester": await Execute(mode, cfg, new Requester(peer), Codecs.Requester); break;
            case "table": await Execute(mode, cfg, new TableProof(peer, output), Codecs.QueryService); break;
            case "query": await Execute(mode, cfg, new QueryProof(peer, output), Codecs.QueryRequester); break;
            default: throw new Exception("Unknown role");
        }
    }
}
