using System.Net;
using System.Net.Sockets;
using System.Runtime.CompilerServices;
using System.Text.Json.Nodes;
using Transit.Station;

internal static class BoundaryProof
{
    private static JsonNode Config() => JsonNode.Parse("""{"realm":72,"principal":1,"pid":1,"generation":3,"timeout_ms":500}""")!;
    [MethodImpl(MethodImplOptions.NoInlining)]
    private static async Task<WeakReference> Abandon(string libraries)
    {
        var server = await GenServer.OpenAsync(libraries, "http://127.0.0.1:1", new byte[32], Config());
        return new WeakReference(server);
    }
    public static async Task Run()
    {
        var libraries = Environment.GetEnvironmentVariable("TRANSIT_LIBRARY_DIR")!;
        using var listener = new TcpListener(IPAddress.Loopback, 0);
        listener.Start();
        var entered = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
        var release = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
        var stalled = Task.Run(async () => {
            using var socket = await listener.AcceptTcpClientAsync();
            await socket.GetStream().ReadAsync(new byte[8192]);
            entered.SetResult();
            await release.Task;
        });
        var server = await GenServer.OpenAsync(libraries,
            $"http://127.0.0.1:{((IPEndPoint)listener.LocalEndpoint).Port}", new byte[32], Config());
        try {
            var operation = server.NextAsync();
            await entered.Task.WaitAsync(TimeSpan.FromSeconds(3));
            try { await server.NextAsync(); throw new Exception("Concurrent call admitted"); }
            catch (TransitException error) when (error.Status == 9) {}
            using var cancellation = new CancellationTokenSource();
            cancellation.Cancel();
            try { await operation.WaitAsync(cancellation.Token); throw new Exception("Await not cancelled"); }
            catch (OperationCanceledException) {}
            var closing = server.DisposeAsync().AsTask();
            int ticks = 0;
            while (!closing.IsCompleted) { await Task.Delay(5); ticks++; }
            await closing;
            if (ticks < 2) throw new Exception("Active native work was freed early or blocked async progress");
            try { await operation; throw new Exception("Stalled request succeeded"); }
            catch (TransitException error) when (error.Status is 6 or 7) {}
            try { await server.NextAsync(); throw new Exception("Closed handle usable"); }
            catch (ObjectDisposedException) {}
        } finally { release.TrySetResult(); await server.DisposeAsync(); await stalled; }
        var abandoned = await Abandon(libraries);
        for (int attempt = 0; attempt < 100 && abandoned.IsAlive; attempt++) {
            await Task.Delay(10); GC.Collect(); GC.WaitForPendingFinalizers();
        }
        if (abandoned.IsAlive) throw new Exception("Idle native worker retained its owner");
        Console.WriteLine(".NET: busy admission, await cancellation, asynchronous close and GC ownership passed");
    }
}
