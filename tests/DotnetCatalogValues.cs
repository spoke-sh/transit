using System.Net;
using System.Net.Sockets;
using System.Reflection;
using System.Runtime.ExceptionServices;
using System.Text.Json.Nodes;
using Transit.Client;
using Transit.Station.Sdk;
using C = Transit.Station.Sdk.Catalog;

internal static class CatalogValues
{
    static void Check(bool value) => Program.Check(value);
    static E Reject<E>(Action action) where E : Exception {
        try { action(); } catch (E error) { return error; }
        throw new Exception("Expected catalog failure");
    }
    static object? Decode(string name, params object?[] args) {
        try { return typeof(C).GetMethod(name, BindingFlags.NonPublic | BindingFlags.Static)!.Invoke(null, args); }
        catch (TargetInvocationException error) { ExceptionDispatchInfo.Capture(error.InnerException!).Throw(); throw; }
    }
    static async Task Expect(ErrorKind kind, Func<Task> action) {
        try { await action(); } catch (TransitException error) { Check(error.Kind == kind); return; }
        throw new Exception("Expected catalog task failure");
    }
    internal static async Task Run(string root) {
        C.Scope scope = new(new ResourceRef(46, 7), ulong.MaxValue);
        Reject<ArgumentException>(() => new C.Scope(scope.Resource, 0));
        Reject<ArgumentException>(() => new C.Connection(new ProcessRef(47, 3), scope));
        foreach (byte[] bytes in new[] { Array.Empty<byte>(), new byte[8193], new byte[] {255} }) Reject<ArgumentException>(() => new C.Prepared(new Bytes(bytes)));
        byte[] original = [1, 2]; C.Prepared prepared = new(new Bytes(original)); original[0] = 0; prepared.Bytes.Copy()[0] = 0; Check(prepared.Bytes.Copy()[0] == 1);
        List<string> names = ["id", "value"]; C.Schema schema = new(names, C.Type.Utf8); names.Clear(); Check(schema.Names.SequenceEqual(new[] {"id", "value"}));
        Reject<NotSupportedException>(() => ((IList<string>)schema.Names)[0] = "changed");
        C.CreateTable request = new(scope, ulong.MaxValue, ulong.MaxValue, uint.MaxValue, "items", schema);
        C.Compiled compiled = new(request, new Bytes(original)); original[0] = 3; Check(compiled.Canonical.Copy()[0] == 0);
        foreach (string json in new[] { "null", "{}", "{\"receipt\":{\"position\":0}}", "{\"receipt\":{\"position\":\"1\"}}", "{\"receipt\":{\"position\":1.5}}", "{\"receipt\":{\"position\":1,\"extra\":true}}", "{\"receipt\":{\"position\":1},\"extra\":true}" })
            Check(Reject<TransitException>(() => Decode("Admission", JsonNode.Parse(json))).Kind == ErrorKind.UnknownOutcome);
        Check(((AdmissionReceipt)Decode("Admission", JsonNode.Parse("{\"receipt\":{\"position\":7}}"))!).Position == 7);
        var receipt = JsonNode.Parse(Program.Obj(("request", Program.Json(request)), ("principal", 17), ("input", 7), ("outcome", "applied")).ToJsonString())!;
        Check(((C.Receipt)Decode("ParseReceipt", receipt, request)!).Request == request);
        foreach (string invalid in new[] { "1", "01", "+1", "18446744073709551616" }) {
            receipt["request"]!["object"] = invalid;
            Reject<TransitException>(() => Decode("ParseReceipt", receipt, request));
        }
        receipt["request"]!["object"] = ulong.MaxValue; Reject<TransitException>(() => Decode("ParseReceipt", receipt, request));

        // Block an actual native HTTP read. Cancellation releases only the wait;
        // the public client remains busy, and disposal must join its ABI worker.
        string seed = Path.Combine(root, "seed"); File.WriteAllText(seed, new string('1', 64));
        using TcpListener listener = new(IPAddress.Loopback, 0); listener.Start();
        var endpoint = new Uri($"http://127.0.0.1:{((IPEndPoint)listener.LocalEndpoint).Port}");
        var client = await C.Client.OpenAsync(new ClientConfig(endpoint, Profile.NativeV1, 10000), new Credential(46, 17, seed), new C.Connection(new ProcessRef(46, 3), scope));
        var worker = typeof(C.Client).GetField("worker", BindingFlags.NonPublic | BindingFlags.Instance)!.GetValue(client)!;
        var thread = (Thread)worker.GetType().GetField("thread", BindingFlags.NonPublic | BindingFlags.Instance)!.GetValue(worker)!;
        using var cancelled = new CancellationTokenSource(); cancelled.Cancel();
        try { await client.DescribeAsync(cancelled.Token); throw new Exception("Precancelled work admitted"); } catch (OperationCanceledException) { }
        Check(!listener.Pending());
        using var cancellation = new CancellationTokenSource(); var pending = client.DescribeAsync(cancellation.Token);
        using var peer = await listener.AcceptTcpClientAsync().WaitAsync(TimeSpan.FromSeconds(5));
        byte[] input = new byte[1]; Check(await peer.GetStream().ReadAsync(input).AsTask().WaitAsync(TimeSpan.FromSeconds(5)) == 1);
        Task? closing = null;
        try {
            cancellation.Cancel(); try { await pending; throw new Exception("Cancellation did not release wait"); } catch (OperationCanceledException) { }
            await Expect(ErrorKind.Busy, () => client.CapabilitiesAsync());
            closing = client.DisposeAsync().AsTask();
            try { await closing.WaitAsync(TimeSpan.FromMilliseconds(100)); throw new Exception("Close abandoned native work"); } catch (TimeoutException) { }
            Check(thread.IsAlive && prepared.Bytes.Copy()[0] == 1);
        } finally { peer.Dispose(); await (closing ?? client.DisposeAsync().AsTask()).WaitAsync(TimeSpan.FromSeconds(15)); }
        Check(!thread.IsAlive); await Expect(ErrorKind.Closed, () => client.CapabilitiesAsync());
        File.Delete(seed);
        Console.WriteLine(".NET catalog immutable values, uncertain receipt decoding and native read cancellation/join passed.");
    }
}
