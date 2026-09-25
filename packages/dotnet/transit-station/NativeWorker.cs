using System.Collections.Concurrent;

namespace Transit.Station;

// One admitted operation, one owned native thread. Default CLR pool stacks are
// smaller than the qualified Debug ABI budget, so Task.Run must not execute FFI.
internal sealed class NativeWorker : IDisposable
{
    private readonly BlockingCollection<Action> queue = new(1);
    private readonly Thread thread;
    private int busy;
    private int stopped;
    public NativeWorker()
    {
        thread = new Thread(() => {
            try {
                while (queue.TryTake(out var action, Timeout.Infinite)) {
                    action();
                    // Do not retain a completed closure/handle while idle.
                    action = null;
                }
            }
            finally { queue.Dispose(); }
        }, Native.MinimumStackBytes) { Name = "transit-native", IsBackground = true };
        thread.Start();
    }
    public Task<T> Invoke<T>(Func<T> function)
    {
        if (Volatile.Read(ref stopped) != 0) return Task.FromException<T>(new ObjectDisposedException("Native worker"));
        if (Interlocked.CompareExchange(ref busy, 1, 0) != 0)
            return Task.FromException<T>(new TransitException(9, "One operation per handle"));
        var result = new TaskCompletionSource<T>(TaskCreationOptions.RunContinuationsAsynchronously);
        try {
            queue.Add(() => {
                T value = default!;
                Exception? error = null;
                try { value = function(); } catch (Exception failure) { error = failure; }
                finally { Volatile.Write(ref busy, 0); }
                if (error is null) result.TrySetResult(value); else result.TrySetException(error);
            });
        } catch (InvalidOperationException) {
            Volatile.Write(ref busy, 0); result.TrySetException(new ObjectDisposedException("Native worker"));
        }
        return result.Task;
    }
    public void Stop()
    {
        if (Interlocked.Exchange(ref stopped, 1) == 0) queue.CompleteAdding();
    }
    public void Dispose() { Stop(); if (Thread.CurrentThread != thread) thread.Join(); }
}
