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
        JsonObject http = Read(Text(cfg, "http_fixtures"));
        Http.Prepared request = await Http.PrepareAsync(new ResourceRef(72, 8), ulong.MaxValue, new(Http.Method.Post, [new Http.Literal("/write")]),
            Convert.FromHexString(Text(http, "body")), new(7, 9000, 2));
        Check(Convert.ToHexString(request.Reference.Copy()).ToLowerInvariant() == Text(http, "reference"));
        Check(System.Text.Encoding.UTF8.GetString(request.Metadata.Copy()) == Text(http, "metadata"));
        byte[] encoded = Convert.FromHexString(Text(http, "outcome"));
        var outcome = (Http.Outcome)await Http.DecodeReplyAsync(72, encoded);
        Check(outcome.Exchange == ulong.MaxValue && outcome.Status == 200 && outcome.Phase == Http.Phase.Observed && outcome.Reference is not null);
        Check(((Http.Outcome)await Http.DecodeReplyAsync(72, Convert.FromHexString(Text(http, "outcome")))).Diagnostic["code"]!.GetValue<string>() == "http.response_observed");
        Check(await Http.DecodeReplyAsync(72, Convert.FromHexString(Text(http, "rejection"))) is Http.Rejected { Reason: Http.Rejection.Denied });
        Http.ReplyCodec<ulong> httpCodec = new(Codecs.U64, 72);
        Check(httpCodec.Decode(httpCodec.Encode(new Http.Application<ulong>(ulong.MaxValue))) is Http.Application<ulong> { Value: ulong.MaxValue });
        Check(httpCodec.Decode(encoded) is Http.Received<ulong> { Value: Http.Outcome { Exchange: ulong.MaxValue } });
        Expect(ErrorKind.Codec, () => httpCodec.Encode(new Http.Received<ulong>(outcome)));
        byte[] releasedBytes = Convert.FromHexString(Text(Read(Text(cfg, "http_release_fixtures")), "reply"));
        var released = (Http.Released)((Http.Received<ulong>)httpCodec.Decode(releasedBytes)).Value;
        Check(released == new Http.Released(new ResourceRef(72, 7), ulong.MaxValue));
        Expect(ErrorKind.Codec, () => httpCodec.Encode(new Http.Received<ulong>(released)));
        try { await Http.DecodeReplyAsync(72, releasedBytes[..19]); throw new Exception("Truncated acknowledgement accepted"); } catch (TransitException) { }
        try { await Http.DecodeReplyAsync(72, encoded[..70]); throw new Exception("Truncated HTTP outcome accepted"); } catch (TransitException) { }
        try { await Http.PrepareAsync(new ResourceRef(72, 8), 1, new(Http.Method.Get, [new Http.Literal("//other/")]), [], new(1, 9000));
            throw new Exception("Invalid HTTP target accepted"); } catch (TransitException) { }
    }
    sealed class HttpBytes : ICodec<Bytes> {
        public string TypeId => "test.http-control"; public uint Version => 1; public int MaxEncodedBytes => 243;
        public byte[] Encode(Bytes value) => value.Copy(); public Bytes Decode(byte[] bytes) => new(bytes);
    }
    sealed class HttpHandler(ProcessRef peer, Http.Prepared request, Http.Outcome? disposal, Http.Outcome? wrongParent, Http.FollowupReason reason) : IHandler<Http.Message<Bytes>> {
        readonly Key<ulong> correlation = new("http-correlation", Codecs.U64);
        readonly Key<ulong> releaseCorrelation = new("http-release-correlation", Codecs.U64);
        readonly Key<ulong> followupCorrelation = new("http-followup-correlation", Codecs.U64);
        public Turn? Escaped; public JsonObject? Result;
        public void OnMessage(Turn turn, Incoming<Http.Message<Bytes>> input) {
            Escaped = turn;
            if (input is Cast<Http.Message<Bytes>>) {
                if (input.Value is Http.Application<Bytes> proposed && proposed.Value.Copy().AsSpan().SequenceEqual("followup"u8)) {
                    Expect(ErrorKind.Handler, () => turn.FollowupHttp(peer, wrongParent!, reason, request));
                    Expect(ErrorKind.Handler, () => turn.FollowupHttp(peer, disposal!, (Http.FollowupReason)100, request));
                    ulong id = turn.FollowupHttp(peer, disposal!, reason, request);
                    turn.State.Put(followupCorrelation, id); Result = new() { ["followup"] = false };
                } else if (input.Value is Http.Application<Bytes> application && application.Value.Copy().AsSpan().SequenceEqual("dispose"u8)) {
                    Expect(ErrorKind.Handler, () => turn.ReleaseHttp(peer, new ResourceRef(73, disposal!.Resource.Resource), disposal.Exchange));
                    ulong id = turn.ReleaseHttp(peer, disposal!.Resource, disposal.Exchange);
                    turn.State.Put(releaseCorrelation, id); Result = new() { ["released"] = false };
                } else if (turn.State.Find(correlation) is not null) Result = new() { ["called"] = true };
                else if (turn.StageHttp(request)) { ulong id = turn.CallHttp(peer, request); turn.State.Put(correlation, id); Result = new() { ["called"] = true }; }
                else Result = new() { ["called"] = false };
            } else {
                var reply = (Reply<Http.Message<Bytes>>)input;
                if (reply.Value is Http.Received<Bytes> { Value: Http.Rejected rejected }) {
                    ulong id = turn.State.Require(followupCorrelation);
                    turn.RequireReply(reply, peer, id); Check(rejected.Reason == Http.Rejection.Denied);
                    var facts = rejected.Diagnostic["facts"]!.AsArray().Where(f => f is not null).ToDictionary(f => f!["field"]!.GetValue<string>());
                    Check(facts["field_path"]!["availability"]!.GetValue<string>() == "provided");
                    Check(ulong.Parse(facts["native_input"]!["value"]!["unsigned"]!.GetValue<string>()) > 0);
                    Check(facts["proposal"]!["value"]!["digest"]!.AsArray().Count == 32);
                    turn.State.Put(new Key<ulong>("http-followup-denied", Codecs.U64), id); Result = new() { ["followup"] = true }; return;
                }
                if (reply.Value is Http.Received<Bytes> { Value: Http.Released released }) {
                    turn.RequireReply(reply, peer, turn.State.Require(releaseCorrelation));
                    Check(released.Resource == disposal!.Resource && released.Exchange == disposal.Exchange);
                    turn.State.Put(new Key<ulong>("http-disposed", Codecs.U64), released.Exchange); Result = new() { ["released"] = true }; return;
                }
                turn.RequireReply(reply, peer, turn.State.Require(correlation));
                Check(reply.Value is Http.Received<Bytes> { Value: Http.Outcome { Phase: Http.Phase.Observed, Status: 200 } });
                turn.State.Put(new Key<ulong>("http-status", Codecs.U64), 200UL); Result = new() { ["observed"] = true };
            }
        }
    }
    static async Task HttpProof(string mode, JsonObject cfg) {
        byte[] body = Convert.FromHexString(Text(cfg, "body"));
        Http.Prepared request = await Http.PrepareAsync(new ResourceRef(72, Number(cfg, "resource")), ulong.MaxValue,
            new(Http.Method.Post, [new Http.Literal("/items/"), new Http.Variable("id", "λ /")], [
                new("X-Tag", [new Http.Literal("one")]), new("X-Tag", [new Http.Literal("two")]),
                new("Authorization", [new Http.Literal("Bearer "), new Http.SecretRef("api", 7)])]), body, new(7, Number(cfg, "deadline")));
        byte original = request.Body.Copy()[0]; body[0] ^= 127; byte[] copy = request.Body.Copy(); copy[0] ^= 1;
        Check(request.Body.Copy()[0] == original && request.Body.Length == 513);
        ServiceConfig config = new(new ClientConfig(new Uri(Text(cfg, "url")), Profile.NativeV1),
            new Activation(new ProcessRef(72, Number(cfg, "pid")), Number(cfg, "generation"), new Credential(72, Number(cfg, "principal"), Text(cfg, "seed_file"))));
        Http.Outcome? disposal = cfg["outcome"] is null ? null : (Http.Outcome)await Http.DecodeReplyAsync(72, Convert.FromHexString(Text(cfg, "outcome")));
        Http.Outcome? wrongParent = cfg["outcome"] is null ? null : (Http.Outcome)await Http.DecodeReplyAsync(73, Convert.FromHexString(Text(cfg, "outcome")));
        Http.FollowupReason reason = cfg["followup_reason"] is null ? Http.FollowupReason.Retry : Enum.Parse<Http.FollowupReason>(Text(cfg, "followup_reason"), true);
        HttpHandler handler = new(new ProcessRef(72, Number(cfg, "peer")), request, disposal, wrongParent, reason);
        await using var runner = await Runner<Http.Message<Bytes>>.OpenAsync(config, handler, new Http.ReplyCodec<Bytes>(new HttpBytes(), 72), FailurePolicy.Stop, new Recovery.FreshOwnership());
        if (mode == "http-async") {
            var active = await runner.OpenHttpAsync((Http.Outcome)await Http.DecodeReplyAsync(72, Convert.FromHexString(Text(cfg, "outcome"))));
            Http.Part first = (await active.ReadAsync())!; Check(first.Data.Length > 0 && !first.Complete);
            File.WriteAllText(Text(cfg, "ready"), ""); await Task.Run(() => WaitFile(Text(cfg, "continue")));
            using var cancellation = new CancellationTokenSource(); Task<Http.Part?> pending = active.ReadAsync(cancellation.Token);
            await Task.Run(() => WaitFile(Text(cfg, "accepted"))); Expect(ErrorKind.Busy, () => active.ReadAsync().GetAwaiter().GetResult());
            cancellation.Cancel(); bool cancelled = false; try { await pending; } catch (OperationCanceledException) { cancelled = true; } Check(cancelled);
            runner.Stop(); Task<RunnerShutdown> closing = runner.CloseAsync(); int beats = 0;
            while (!closing.IsCompleted) { beats++; await Task.Delay(10); } await closing; Check(beats > 5 && first.Data.Length > 0);
            Expect(ErrorKind.Closed, () => active.ReadAsync().GetAwaiter().GetResult()); Report(new() { ["joined"] = true }); return;
        }
        Http.Reader? reader = null; Http.Outcome? outcome = null; using MemoryStream owned = new();
        for (string? line; (line = Console.ReadLine()) is not null;) {
            switch (line) {
                case "step":
                    bool committed = false; for (int n = 0; n < 32; n++) if (await runner.NextAsync() is Committed) { committed = true; break; }
                    Check(committed); Expect(ErrorKind.TurnExpired, () => handler.Escaped!.StageHttp(request));
                    Expect(ErrorKind.TurnExpired, () => handler.Escaped!.ReleaseHttp(new ProcessRef(72, Number(cfg, "peer")), request.Resource, 1));
                    Expect(ErrorKind.TurnExpired, () => handler.Escaped!.FollowupHttp(new ProcessRef(72, Number(cfg, "peer")), disposal!, reason, request)); Report(handler.Result!); break;
                case "open":
                    outcome = (Http.Outcome)await Http.DecodeReplyAsync(72, Convert.FromHexString(Text(cfg, "outcome")));
                    Check(await runner.HttpDiagnosticAsync(outcome) is null);
                    var evidence = (await runner.HttpDiagnosticAsync(outcome, ExchangeDiagnosticKind.NativeEffect))!;
                    Check(evidence["code"]!.GetValue<string>() == "effect.result_recorded" && evidence["outcome"]!.GetValue<string>() == "completed");
                    Check(evidence["identity"]!["id"]!.GetValue<string>() == outcome.Effect.ToString());
                    reader = await runner.OpenHttpAsync(outcome);
                    Expect(ErrorKind.Busy, () => runner.OpenHttpAsync(outcome).GetAwaiter().GetResult());
                    var first = (await reader.ReadAsync())!; Check(first.Data.Length > 0 && !first.Complete); Report(new() { ["prefix"] = true }); break;
                case "denied": Expect(ErrorKind.AccessDenied, () => reader!.ReadAsync().GetAwaiter().GetResult()); Report(new() { ["denied"] = true }); break;
                case "reopen":
                    try { await reader!.ReadAsync(); throw new Exception("Failed HTTP reader resumed"); }
                    catch (TransitException error) { Check(error.Kind == ErrorKind.ReadFailed && error.Code == "HttpReplayFailed"); }
                    await reader!.CloseAsync(); await reader.CloseAsync(); reader = await runner.OpenHttpAsync(outcome!);
                    while (await reader.ReadAsync() is { } part) if (part.Kind == Http.PartKind.ResponseBody) owned.Write(part.Data.Copy());
                    Check(reader.Complete); await reader.CloseAsync(); Report(new() { ["complete"] = true, ["body"] = Convert.ToHexString(owned.ToArray()).ToLowerInvariant() }); break;
                case "close":
                    await runner.CloseAsync(); if (reader is not null) Expect(ErrorKind.Closed, () => reader.ReadAsync().GetAwaiter().GetResult());
                    Report(new() { ["closed"] = true, ["owned"] = Convert.ToHexString(owned.ToArray()).ToLowerInvariant() }); return;
                default: throw new Exception("Unknown HTTP command");
            }
        }
    }
    static async Task GrpcGolden(JsonObject cfg) {
        var fixture=Read(Text(cfg,"grpc_fixtures")); byte[] encoded=Convert.FromHexString(Text(fixture,"outcome_ok_hex"));
        var ok=(Grpc.Outcome)await Grpc.DecodeReplyAsync(72,encoded);
        Check(ok.Diagnostic["code"]!.GetValue<string>() == "grpc.ok_observed");
        Check(ok.Phase==Grpc.Phase.Observed && ok.Status==0 && ok.Exchange==ulong.MaxValue && ok.Reference is not null);
        var unknown=(Grpc.Outcome)await Grpc.DecodeReplyAsync(72,Convert.FromHexString(Text(fixture,"outcome_unknown_hex")));
        Check(unknown.Diagnostic["outcome"]!.GetValue<string>() == "closed_unknown");
        Check(unknown.Phase==Grpc.Phase.ClosedUnknown && unknown.Status is null && unknown.Reference is null);
        Check(await Grpc.DecodeReplyAsync(72,Convert.FromHexString(Text(fixture,"rejection_hex"))) is Grpc.Rejected {Reason: Grpc.Rejection.Denied});
        Check(await Grpc.DecodeReplyAsync(72,Convert.FromHexString(Text(fixture,"released_hex"))) == new Grpc.Released(new ResourceRef(72,7),ulong.MaxValue));
        Grpc.ReplyCodec<ulong> codec=new(Codecs.U64,72);
        Check(codec.Decode(codec.Encode(new Grpc.Application<ulong>(ulong.MaxValue))) is Grpc.Application<ulong> {Value: ulong.MaxValue});
        Check(codec.Decode(encoded) is Grpc.Received<ulong> {Value: Grpc.Outcome {Status: 0}});
        Expect(ErrorKind.Codec,()=>codec.Encode(new Grpc.Received<ulong>(ok)));
        try { await Grpc.DecodeReplyAsync(72,encoded[..72]); throw new Exception("Truncated RPC accepted"); } catch(TransitException) { }
    }
    sealed class GrpcBytes : ICodec<Bytes> {
        public string TypeId => "test.grpc-control"; public uint Version => 1; public int MaxEncodedBytes => 243;
        public byte[] Encode(Bytes value) => value.Copy(); public Bytes Decode(byte[] bytes) => new(bytes);
    }
    sealed class GrpcHandler(ProcessRef peer, Grpc.Prepared request, Grpc.Outcome? disposal, Grpc.Outcome? wrongParent) : IHandler<Grpc.Message<Bytes>> {
        readonly Key<ulong> correlation = new("grpc-correlation", Codecs.U64);
        readonly Key<ulong> releaseCorrelation = new("grpc-release-correlation", Codecs.U64);
        readonly Key<ulong> followupCorrelation = new("grpc-followup-correlation", Codecs.U64);
        public Turn? Escaped; public JsonObject? Result;
        public void OnMessage(Turn turn, Incoming<Grpc.Message<Bytes>> input) {
            Escaped = turn;
            if (input is Cast<Grpc.Message<Bytes>>) {
                if (input.Value is Grpc.Application<Bytes> proposed && proposed.Value.Copy().AsSpan().SequenceEqual("followup"u8)) {
                    Expect(ErrorKind.Handler, () => turn.RetryGrpc(peer, wrongParent!, request));
                    ulong id = turn.RetryGrpc(peer, disposal!, request);
                    turn.State.Put(followupCorrelation, id); Result = new() { ["followup"] = false };
                } else if (input.Value is Grpc.Application<Bytes> application && application.Value.Copy().AsSpan().SequenceEqual("dispose"u8)) {
                    Expect(ErrorKind.Handler, () => turn.ReleaseGrpc(peer, new ResourceRef(73, disposal!.Resource.Resource), disposal.Exchange));
                    ulong id = turn.ReleaseGrpc(peer, disposal!.Resource, disposal.Exchange);
                    turn.State.Put(releaseCorrelation, id); Result = new() { ["released"] = false };
                } else if (turn.State.Find(correlation) is not null) Result = new() { ["called"] = true };
                else if (turn.StageGrpc(request)) { ulong id = turn.CallGrpc(peer, request); turn.State.Put(correlation, id); Result = new() { ["called"] = true }; }
                else Result = new() { ["called"] = false };
            } else {
                var reply = (Reply<Grpc.Message<Bytes>>)input;
                if (reply.Value is Grpc.Received<Bytes> { Value: Grpc.Rejected rejected }) {
                    ulong id = turn.State.Require(followupCorrelation);
                    turn.RequireReply(reply, peer, id); Check(rejected.Reason == Grpc.Rejection.Denied);
                    var facts = rejected.Diagnostic["facts"]!.AsArray().Where(f => f is not null).ToDictionary(f => f!["field"]!.GetValue<string>());
                    Check(facts["field_path"]!["availability"]!.GetValue<string>() == "provided");
                    Check(ulong.Parse(facts["native_input"]!["value"]!["unsigned"]!.GetValue<string>()) > 0);
                    Check(facts["proposal"]!["value"]!["digest"]!.AsArray().Count == 32);
                    turn.State.Put(new Key<ulong>("grpc-followup-denied", Codecs.U64), id); Result = new() { ["followup"] = true }; return;
                }
                if (reply.Value is Grpc.Received<Bytes> { Value: Grpc.Released released }) {
                    turn.RequireReply(reply, peer, turn.State.Require(releaseCorrelation));
                    Check(released.Resource == disposal!.Resource && released.Exchange == disposal.Exchange);
                    turn.State.Put(new Key<ulong>("grpc-disposed", Codecs.U64), released.Exchange); Result = new() { ["released"] = true }; return;
                }
                turn.RequireReply(reply, peer, turn.State.Require(correlation));
                Check(reply.Value is Grpc.Received<Bytes> { Value: Grpc.Outcome { Phase: Grpc.Phase.Observed, Status: 0 } });
                turn.State.Put(new Key<ulong>("grpc-status", Codecs.U64), 0UL); Result = new() { ["observed"] = true };
            }
        }
    }
    static async Task GrpcProof(string mode, JsonObject cfg) {
        byte[] body = Convert.FromHexString(Text(cfg, "body"));
        var method = await Grpc.BindMethodAsync(Convert.FromHexString(Text(cfg,"descriptor")),"/test.Peer/Bidi");
        Check(method.Shape == Grpc.Shape.Bidi);
        Bytes message=new(body);
        Grpc.Prepared request = await Grpc.PrepareAsync(new ResourceRef(72,Number(cfg,"resource")),ulong.MaxValue,
            new(method,[new("x-tag",new Grpc.Literal(new Bytes("one"u8.ToArray()))),new("x-tag",new Grpc.Literal(new Bytes("two"u8.ToArray()))),
                new("x-data-bin",new Grpc.Literal(new Bytes([0,255]))),new("authorization",new Grpc.SecretRef("api",7))]),
            [message,new Bytes([])],new(7,Number(cfg,"deadline")));
        byte[] original=request.Batch.Copy(); body[0]^=127; byte[] copy=request.Batch.Copy(); copy[0]^=1;
        Check(original.AsSpan().SequenceEqual(request.Batch.Copy()) && request.Batch.Length==message.Length+16);
        ServiceConfig config = new(new ClientConfig(new Uri(Text(cfg, "url")), Profile.NativeV1),
            new Activation(new ProcessRef(72, Number(cfg, "pid")), Number(cfg, "generation"), new Credential(72, Number(cfg, "principal"), Text(cfg, "seed_file"))));
        Grpc.Outcome? disposal = cfg["outcome"] is null ? null : (Grpc.Outcome)await Grpc.DecodeReplyAsync(72, Convert.FromHexString(Text(cfg, "outcome")));
        Grpc.Outcome? wrongParent = cfg["outcome"] is null ? null : (Grpc.Outcome)await Grpc.DecodeReplyAsync(73, Convert.FromHexString(Text(cfg, "outcome")));
        GrpcHandler handler = new(new ProcessRef(72, Number(cfg, "peer")), request, disposal, wrongParent);
        await using var runner = await Runner<Grpc.Message<Bytes>>.OpenAsync(config, handler, new Grpc.ReplyCodec<Bytes>(new GrpcBytes(), 72), FailurePolicy.Stop, new Recovery.FreshOwnership());
        if (mode == "grpc-async") {
            var active = await runner.OpenGrpcAsync((Grpc.Outcome)await Grpc.DecodeReplyAsync(72, Convert.FromHexString(Text(cfg, "outcome"))));
            Grpc.Part first = (await active.ReadAsync())!; Check(first.Data.Length > 0 && !first.Complete);
            File.WriteAllText(Text(cfg, "ready"), ""); await Task.Run(() => WaitFile(Text(cfg, "continue")));
            using var cancellation = new CancellationTokenSource(); Task<Grpc.Part?> pending = active.ReadAsync(cancellation.Token);
            await Task.Run(() => WaitFile(Text(cfg, "accepted"))); Expect(ErrorKind.Busy, () => active.ReadAsync().GetAwaiter().GetResult());
            cancellation.Cancel(); bool cancelled = false; try { await pending; } catch (OperationCanceledException) { cancelled = true; } Check(cancelled);
            runner.Stop(); Task<RunnerShutdown> closing = runner.CloseAsync(); int beats = 0;
            while (!closing.IsCompleted) { beats++; await Task.Delay(10); } await closing; Check(beats > 5 && first.Data.Length > 0);
            Expect(ErrorKind.Closed, () => active.ReadAsync().GetAwaiter().GetResult()); Report(new() { ["joined"] = true }); return;
        }
        Grpc.Reader? reader = null; Grpc.Outcome? outcome = null; using MemoryStream owned = new();
        for (string? line; (line = Console.ReadLine()) is not null;) {
            switch (line) {
                case "step":
                    bool committed = false; for (int n = 0; n < 32; n++) if (await runner.NextAsync() is Committed) { committed = true; break; }
                    Check(committed); Expect(ErrorKind.TurnExpired, () => handler.Escaped!.StageGrpc(request));
                    Expect(ErrorKind.TurnExpired, () => handler.Escaped!.ReleaseGrpc(new ProcessRef(72, Number(cfg, "peer")), request.Resource, 1));
                    Expect(ErrorKind.TurnExpired, () => handler.Escaped!.RetryGrpc(new ProcessRef(72, Number(cfg, "peer")), disposal!, request)); Report(handler.Result!); break;
                case "open":
                    outcome = (Grpc.Outcome)await Grpc.DecodeReplyAsync(72, Convert.FromHexString(Text(cfg, "outcome")));
                    Check(await runner.GrpcDiagnosticAsync(outcome) is null);
                    var evidence = (await runner.GrpcDiagnosticAsync(outcome, ExchangeDiagnosticKind.NativeEffect))!;
                    Check(evidence["code"]!.GetValue<string>() == "effect.result_recorded" && evidence["outcome"]!.GetValue<string>() == "completed");
                    Check(evidence["identity"]!["id"]!.GetValue<string>() == outcome.Effect.ToString());
                    reader = await runner.OpenGrpcAsync(outcome);
                    Expect(ErrorKind.Busy, () => runner.OpenGrpcAsync(outcome).GetAwaiter().GetResult());
                    var first = (await reader.ReadAsync())!; Check(first.Data.Length > 0 && !first.Complete); Report(new() { ["prefix"] = true }); break;
                case "denied": Expect(ErrorKind.AccessDenied, () => reader!.ReadAsync().GetAwaiter().GetResult()); Report(new() { ["denied"] = true }); break;
                case "reopen":
                    try { await reader!.ReadAsync(); throw new Exception("Failed RPC reader resumed"); }
                    catch (TransitException error) { Check(error.Kind == ErrorKind.ReadFailed && error.Code == "GrpcReplayFailed"); }
                    await reader!.CloseAsync(); await reader.CloseAsync(); reader = await runner.OpenGrpcAsync(outcome!);
                    while (await reader.ReadAsync() is { } part) if (part.Kind == Grpc.PartKind.ResponseBody) owned.Write(part.Data.Copy());
                    Check(reader.Complete); await reader.CloseAsync(); Report(new() { ["complete"] = true, ["body"] = Convert.ToHexString(owned.ToArray()).ToLowerInvariant() }); break;
                case "close":
                    await runner.CloseAsync(); if (reader is not null) Expect(ErrorKind.Closed, () => reader.ReadAsync().GetAwaiter().GetResult());
                    Report(new() { ["closed"] = true, ["owned"] = Convert.ToHexString(owned.ToArray()).ToLowerInvariant() }); return;
                default: throw new Exception("Unknown RPC command");
            }
        }
    }
    static async Task Execute<T>(string mode, JsonObject cfg, IHandler<T> handler, ICodec<T> codec) where T : notnull {
        ulong realm = Number(cfg, "realm");
        var config = new ServiceConfig(new ClientConfig(new Uri(Text(cfg, "url")), Profile.NativeV1),
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
                if (line == "ready") { Report(new() { ["ready"] = true }); continue; }
                if (line == "close") { await runner.CloseAsync(); if (handler is QueryProof query) query.SaveOwned(); if (handler is TableProof table) table.Expired(); Report(new() { ["closed"] = true }); break; }
                Check(line is "one" or "reconcile"); RunnerEvent? ev = null;
                try {
                    for (int count = 0; count < 32; count++) { ev = await (line == "reconcile" && count == 0 ? runner.ReconcileAsync() : runner.NextAsync()); if (ev is not Progress) break; }
                } catch (TransitException error) when (error.Status == 7) {
                    Report(new() { ["event"] = "ReadUnavailable", ["code"] = error.Code }); continue;
                }
                if (ev is NeedsRecovery paused) Check(paused.Mutation.Export().AsSpan().SequenceEqual(File.ReadAllBytes(store.Pending)));
                var response = new JsonObject { ["event"] = ev!.GetType().Name };
                if (ev is NeedsRecovery recoveryEvent) { response["phase"] = recoveryEvent.Phase; response["code"] = recoveryEvent.Error.Code; }
                Report(response);
            }
        }
    }
    sealed class DocumentHandler(IReadOnlyList<Document.Prepared> changes) : IHandler<Bytes>
    {
        public Document.Phase? Phase; public Document.Owner? Escaped;
        public void Initialize(Turn turn) => turn.Document(ulong.MaxValue).Create(1);
        public void OnMessage(Turn turn,Incoming<Bytes> input) {
            var owner=turn.Document(ulong.MaxValue); Escaped=owner; Phase=null;
            string command=System.Text.Encoding.UTF8.GetString(((Cast<Bytes>)input).Value.Copy());
            switch(command) {
                case "initialize": return;
                case "checkpoint": Phase=owner.Checkpoint(90).Phase; return;
                case "window": owner.MergeWindow(2); return;
                case "retire": owner.Retire(); return;
                case "0": case "1": int index=int.Parse(command,System.Globalization.CultureInfo.InvariantCulture); Phase=owner.Stage((ulong)index+1,changes[index],256).Phase; return;
                default: throw new Exception("Unknown Document tick");
            }
        }
    }
    static async Task DocumentProof(string mode,JsonObject cfg) {
        ResourceRef resource=new(72,Number(cfg,"resource"));
        if(mode=="document-codecs") {
            JsonObject fixtures=Read(Text(cfg,"document_fixtures"));
            foreach(var item in fixtures["changes"]!.AsArray()) {
                byte[] bytes=Convert.FromHexString(Text(item!.AsObject(),"wire_hex"));
                Check((await Document.PrepareAsync(await Document.DecodeAsync(bytes))).Bytes.Copy().AsSpan().SequenceEqual(bytes));
                foreach(int size in new[]{0,1,bytes.Length-1}) { bool rejected=false; try { await Document.DecodeAsync(bytes[..size]); } catch(Exception error) when(error is TransitException or ArgumentException) { rejected=true; } Check(rejected); }
            }
            byte[] encoded=Convert.FromHexString(Text(fixtures,"reference_hex")); var reference=await Document.Reference.DecodeAsync(72,encoded);
            Check(reference.DocumentId==ulong.MaxValue && reference.Revision==ulong.MaxValue && reference.Bytes.Copy().AsSpan().SequenceEqual(encoded));
            Document.Change change=new(ulong.MaxValue,1,1,ulong.MaxValue,0,1,[
                new Document.Assign(default,"value",[],new Document.Signed(long.MinValue)),
                new Document.Assign(default,"body",[],new Document.Container(Document.ContainerKind.Text)),
                new Document.Insert(new(2,ulong.MaxValue),default,new Document.CharacterValue(new System.Text.Rune(0x1f642)))]);
            var prepared=await Document.PrepareAsync(change); byte[] copy=prepared.Bytes.Copy(); copy[0]^=127;
            Check(Convert.ToHexString(prepared.Bytes.Copy()).ToLowerInvariant()==cfg["changes"]![0]!.GetValue<string>());
            bool invalid=false; try { _=new Document.StringValue("\ud800"); } catch(ArgumentException) { invalid=true; } Check(invalid);
            Report(new(){["codecs"]=true}); return;
        }
        List<Document.Prepared> changes=[];
        foreach(var item in cfg["changes"]!.AsArray()) changes.Add(await Document.PrepareAsync(await Document.DecodeAsync(Convert.FromHexString(item!.GetValue<string>()))));
        ServiceConfig config=new(new ClientConfig(new Uri(Text(cfg,"url")),Profile.NativeV1),new Activation(new ProcessRef(72,Number(cfg,"pid")),Number(cfg,"generation"),new Credential(72,Number(cfg,"principal"),Text(cfg,"seed_file"))));
        DocumentHandler handler=new(changes); Document.Reference? saved=null;
        await using var runner=await Runner<Bytes>.OpenAsync(config,handler,new GrpcBytes(),FailurePolicy.Stop,new Recovery.FreshOwnership()); var reader=runner.Documents;
        for(string? command;(command=Console.ReadLine()) is not null;) {
            switch(command) {
                case "one": {
                    bool committed=false; for(int i=0;i<12;i++) { var next=await runner.NextAsync(); if(next is Committed) { committed=true; break; } Check(next is Progress); }
                    Check(committed); Expect(ErrorKind.TurnExpired,() => handler.Escaped!.MergeWindow(0));
                    string? phase=handler.Phase switch { Document.Phase.Progress=>"progress",Document.Phase.Accepted=>"accepted",Document.Phase.Duplicate=>"duplicate",Document.Phase.CheckpointComplete=>"checkpoint_complete",null=>null,_=>throw new Exception("Invalid phase") };
                    Report(new(){["event"]="committed",["phase"]=phase}); break;
                }
                case "read": {
                    var description=await reader.DescribeAsync(resource,ulong.MaxValue); var reference=description.Reference; Check(description.Floor==0 && description.MergeWindow==0);
                    var field=await reader.PathAsync(reference,["value"]); var page=await reader.SequenceAsync(reference,new(2,ulong.MaxValue)); Check(page.Next is null);
                    string text=string.Concat(page.Items.Select(v => ((Document.CharacterValue)v.Field.Assignments[0].Value).Value.ToString())); bool initial=reference.Revision==2;
                    Check(text==(initial?"🙂":"🙂́") && ((Document.Signed)field.Field.Assignments[0].Value).Value==long.MinValue);
                    Check((await reader.PathAsync(reference,["missing"])).Field.Status==Document.Status.Missing);
                    Check((await Document.PrepareAsync(await reader.AcceptedChangeAsync(reference))).Bytes.Equals(changes[(int)reference.Revision-2].Bytes));
                    Check(field.Field.Status==(initial?Document.Status.Scalar:Document.Status.Conflict)); saved??=reference;
                    Report(new(){["revision"]=reference.Revision.ToString(System.Globalization.CultureInfo.InvariantCulture),["items"]=page.Items.Count,["status"]=initial?"scalar":"conflict"}); break;
                }
                case "old": Check((await reader.PathAsync(saved!,["value"])).Field.Status==Document.Status.Scalar); Report(new(){["retained"]=true}); break;
                case "denied": Expect(ErrorKind.AccessDenied,() => reader.PathAsync(saved!,["value"]).GetAwaiter().GetResult()); Report(new(){["denied"]=true}); break;
                case "resynchronize": { var result=await reader.ResynchronizeAsync(resource,ulong.MaxValue,ulong.MaxValue); Check(result.Reference.Revision==3); Report(new(){["previous"]=result.PreviousCounter.ToString(System.Globalization.CultureInfo.InvariantCulture),["clock"]=result.Clock.ToString(System.Globalization.CultureInfo.InvariantCulture)}); break; }
                case "retired": Check((await reader.DescribeAsync(resource,ulong.MaxValue)).Retired); try { await reader.PathAsync(saved!,["value"]); throw new Exception("Retired read accepted"); } catch(TransitException error) { Check(error.Code=="DocumentRetired"); } Report(new(){["retired"]=true}); break;
                case "async-close": {
                    var other=await Runner<Bytes>.OpenAsync(config,new DocumentHandler(changes),new GrpcBytes(),FailurePolicy.Stop,new Recovery.FreshOwnership()); var active=other.Documents;
                    using CancellationTokenSource cancellation=new(); var pending=active.DescribeAsync(resource,ulong.MaxValue,cancellation.Token); cancellation.Cancel();
                    try { await pending; } catch(OperationCanceledException) {} await other.DisposeAsync();
                    Expect(ErrorKind.Closed,() => active.DescribeAsync(resource,ulong.MaxValue).GetAwaiter().GetResult()); Report(new(){["joined"]=true}); break;
                }
                case "close": await runner.DisposeAsync(); Expect(ErrorKind.Closed,() => reader.DescribeAsync(resource,ulong.MaxValue).GetAwaiter().GetResult()); Report(new(){["closed"]=true}); return;
                default: throw new Exception("Unknown Document command");
            }
        }
    }

    public static async Task Main(string[] args) {
        string mode = args[0], path = args[1]; var cfg = Read(path);
        Check(typeof(Runner<>).Assembly.Location.StartsWith(Path.GetDirectoryName(path)!, StringComparison.Ordinal)); Check(Text(cfg, "profile") == "native_v1");
        if (mode.StartsWith("document-", StringComparison.Ordinal)) { await DocumentProof(mode,cfg); return; }
        if (mode=="grpc-golden") { await GrpcGolden(cfg); return; }
        if (mode.StartsWith("grpc-", StringComparison.Ordinal)) { await GrpcProof(mode, cfg); return; }
        if (mode.StartsWith("http-", StringComparison.Ordinal)) { await HttpProof(mode, cfg); return; }
        if (mode == "codecs") { await CodecsProof(cfg); return; }
        if (mode == "recover") { await using var client = await SdkClient.OpenAsync(new ClientConfig(new Uri(Text(cfg, "url")), Profile.NativeV1));
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
