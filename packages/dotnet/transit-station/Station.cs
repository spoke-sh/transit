using System.Runtime.InteropServices;
using System.Text;
using System.Text.Json.Nodes;
using Microsoft.Win32.SafeHandles;

namespace Transit.Station;

public sealed class TransitException(uint status, string? detail) : Exception($"Transit status {status}: {detail}")
{
    public uint Status { get; } = status;
    public string? Detail { get; } = detail;
}
internal static class Libraries
{
    private static readonly object gate = new();
    private static string? directory;
    internal static void Load(string path)
    {
        path = Path.GetFullPath(path);
        lock (gate) {
            if (directory is not null) {
                if (directory != path) throw new InvalidOperationException("One native ABI directory per assembly");
                return;
            }
            NativeLibrary.SetDllImportResolver(typeof(Native).Assembly, (name, _, _) =>
                NativeLibrary.Load(Path.Combine(path, $"lib{name}.so")));
            directory = path;
        }
    }
    internal static byte[] Json(JsonNode value) => Encoding.UTF8.GetBytes(value.ToJsonString());
    internal static readonly UTF8Encoding Utf8 = new(false, true);
}
internal sealed class ServerHandle : SafeHandleZeroOrMinusOneIsInvalid
{
    internal ServerHandle(IntPtr value) : base(true) { SetHandle(value); }
    protected override bool ReleaseHandle() { Native.station_server_destroy(handle); return true; }
}
internal sealed class ClientHandle : SafeHandleZeroOrMinusOneIsInvalid
{
    internal ClientHandle(IntPtr value) : base(true) { SetHandle(value); }
    protected override bool ReleaseHandle() { Native.transit_client_destroy(handle); return true; }
}
internal sealed class BufferHandle : SafeHandleZeroOrMinusOneIsInvalid
{
    private readonly bool station;
    internal BufferHandle(IntPtr value, bool station) : base(true) { SetHandle(value); this.station = station; }
    internal string Text()
    {
        if (IsInvalid) return "null";
        nuint size = station ? Native.station_buffer_size(handle) : Native.transit_buffer_size(handle);
        if (size > 256 * 1024 * 2 + 16384) throw new TransitException(8, "Oversized native buffer");
        var bytes = new byte[(int)size];
        Marshal.Copy(station ? Native.station_buffer_data(handle) : Native.transit_buffer_data(handle), bytes, 0, bytes.Length);
        return Libraries.Utf8.GetString(bytes);
    }
    protected override bool ReleaseHandle()
    {
        if (station) Native.station_buffer_destroy(handle); else Native.transit_buffer_destroy(handle);
        return true;
    }
    internal static string Result(uint status, IntPtr pointer, bool station)
    {
        using var result = new BufferHandle(pointer, station);
        var text = result.Text();
        if (status != 0) throw new TransitException(status, text);
        return text;
    }
}
public sealed class GenServer : IDisposable, IAsyncDisposable
{
    private readonly NativeWorker worker;
    private readonly ServerHandle handle;
    private int disposed;
    private GenServer(NativeWorker worker, IntPtr pointer) { this.worker = worker; handle = new ServerHandle(pointer); }
    private Task<T> Invoke<T>(Func<T> action) => worker.Invoke(() => {
        try { return action(); } finally { GC.KeepAlive(handle); }
    });
    public static async Task<GenServer> OpenAsync(string libraries, string url, byte[] seed, JsonNode config)
    {
        Libraries.Load(libraries);
        if (seed.Length != 32) throw new ArgumentException("Expected a 32-byte seed");
        byte[] key = (byte[])seed.Clone(), endpoint = Encoding.UTF8.GetBytes(url), document = Libraries.Json(config);
        var worker = new NativeWorker();
        try {
            var pointer = await worker.Invoke(() => {
                var status = Native.station_server_create(Native.Version, endpoint, (nuint)endpoint.Length, key, document, (nuint)document.Length, out var pointer);
                if (status != 0) throw new TransitException(status, null);
                return pointer;
            }).ConfigureAwait(false);
            return new GenServer(worker, pointer);
        } catch { worker.Dispose(); throw; }
        finally { Array.Clear(key); }
    }
    public Task<JsonNode?> NextAsync(ulong? deadlineMs = null) => Invoke(() => {
        var status = Native.station_server_next(handle.DangerousGetHandle(), deadlineMs ?? (ulong)DateTimeOffset.UtcNow.ToUnixTimeMilliseconds() + 30000, out var result);
        return JsonNode.Parse(BufferHandle.Result(status, result, true));
    });
    public Task<JsonNode?> ApplyAsync(JsonNode action)
    {
        var json = Libraries.Json(action);
        return Invoke(() => {
            var status = Native.station_server_apply(handle.DangerousGetHandle(), json, (nuint)json.Length, out var result);
            return JsonNode.Parse(BufferHandle.Result(status, result, true));
        });
    }
    public Task FinishAsync(bool failed = false) => Invoke(() => {
        var status = Native.station_server_finish(handle.DangerousGetHandle(), failed ? 1u : 0u);
        if (status != 0) throw new TransitException(status, null);
        return true;
    });
    public Task<string> PendingAsync() => Invoke(() => {
        var status = Native.station_server_pending(handle.DangerousGetHandle(), out var result);
        return BufferHandle.Result(status, result, true);
    });
    public Task<JsonNode?> ArrowCellAsync(byte[] ipc, uint row, uint column)
    {
        var bytes = (byte[])ipc.Clone();
        return Invoke(() => {
            var status = Native.station_arrow_cell(bytes, (nuint)bytes.Length, row, column, out var result);
            return JsonNode.Parse(BufferHandle.Result(status, result, true));
        });
    }
    public void Dispose()
    {
        if (Interlocked.Exchange(ref disposed, 1) != 0) return;
        worker.Dispose(); handle.Dispose(); GC.SuppressFinalize(this);
    }
    public ValueTask DisposeAsync() => new(Task.Run(Dispose));
    ~GenServer() { worker?.Stop(); }
}
public sealed class Client : IDisposable, IAsyncDisposable
{
    private readonly NativeWorker worker;
    private readonly ClientHandle handle;
    private int disposed;
    private Client(NativeWorker worker, IntPtr pointer) { this.worker = worker; handle = new ClientHandle(pointer); }
    private Task<T> Invoke<T>(Func<T> action) => worker.Invoke(() => {
        try { return action(); } finally { GC.KeepAlive(handle); }
    });
    public static async Task<Client> OpenAsync(string libraries, string url, uint timeoutMs = 5000)
    {
        Libraries.Load(libraries);
        byte[] endpoint = Encoding.UTF8.GetBytes(url);
        var worker = new NativeWorker();
        try {
            var pointer = await worker.Invoke(() => {
                var status = Native.transit_client_create(Native.ClientVersion, endpoint, (nuint)endpoint.Length, timeoutMs, out var pointer);
                if (status != 0) throw new TransitException(status, null);
                return pointer;
            }).ConfigureAwait(false);
            return new Client(worker, pointer);
        } catch { worker.Dispose(); throw; }
    }
    public async Task<string> PrepareAsync(uint kind, byte[] seed, JsonNode document)
    {
        if (seed.Length != 32) throw new ArgumentException("Expected a 32-byte seed");
        byte[] key = (byte[])seed.Clone(), json = Libraries.Json(document);
        try { return await Invoke(() => {
            IntPtr operation = IntPtr.Zero;
            try {
                var status = Native.transit_operation_prepare(kind, key, json, (nuint)json.Length, out operation);
                if (status != 0) throw new TransitException(status, null);
                status = Native.transit_operation_export(operation, out var result);
                return BufferHandle.Result(status, result, false);
            } finally { Native.transit_operation_destroy(operation); }
        }).ConfigureAwait(false); }
        finally { Array.Clear(key); }
    }
    public Task<JsonNode?> CallAsync(string frozen)
    {
        var json = Encoding.UTF8.GetBytes(frozen);
        return Invoke(() => {
            IntPtr operation = IntPtr.Zero;
            try {
                var status = Native.transit_operation_import(json, (nuint)json.Length, out operation);
                if (status != 0) throw new TransitException(status, null);
                status = Native.transit_client_call(handle.DangerousGetHandle(), operation, out var result);
                return JsonNode.Parse(BufferHandle.Result(status, result, false));
            } finally { Native.transit_operation_destroy(operation); }
        });
    }
    public void Dispose()
    {
        if (Interlocked.Exchange(ref disposed, 1) != 0) return;
        worker.Dispose(); handle.Dispose(); GC.SuppressFinalize(this);
    }
    public ValueTask DisposeAsync() => new(Task.Run(Dispose));
    ~Client() { worker?.Stop(); }
}
