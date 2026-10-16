using System.Collections.Concurrent;

namespace Transit.Client.Internal;

internal interface IWorkerState<E> : IDisposable { E Evidence(); }

/// <summary>One admitted job and an independent close signal, on an 8 MiB native stack.</summary>
internal sealed class Worker<S, E> where S : IWorkerState<E>
{
    private readonly object gate = new();
    private readonly BlockingCollection<Action<S>> queue = new(1);
    private readonly Thread thread;
    private readonly TaskCompletionSource<E> closed = new(TaskCreationOptions.RunContinuationsAsynchronously);
    private bool busy, closing;
    internal E? RetainedEvidence { get; private set; }
    private Worker(Func<S> factory, int stackBytes, TaskCompletionSource<Worker<S, E>> ready)
    {
        thread = new Thread(() => {
            S state;
            try { state = factory(); }
            catch (Exception error) { ready.TrySetException(error); queue.Dispose(); return; }
            ready.TrySetResult(this);
            try {
                foreach (var job in queue.GetConsumingEnumerable()) {
                    job(state);
                }
            } finally {
                Exception? failure = null;
                try { RetainedEvidence = state.Evidence(); } catch (Exception error) { failure = error; }
                try { state.Dispose(); } catch (Exception error) { failure ??= error; }
                queue.Dispose();
                if (failure is null) closed.TrySetResult(RetainedEvidence!);
                else closed.TrySetException(new TransitException(ErrorKind.Cleanup, "worker-close"));
            }
        }, stackBytes) { Name = "transit-owned-native", IsBackground = true };
        thread.Start();
    }
    internal static Task<Worker<S, E>> OpenAsync(Func<S> factory, int stackBytes)
    {
        TaskCompletionSource<Worker<S, E>> ready = new(TaskCreationOptions.RunContinuationsAsynchronously);
        _ = new Worker<S, E>(factory, stackBytes, ready);
        return ready.Task;
    }
    internal Task<T> Invoke<T>(Func<S, T> function, CancellationToken cancellation = default) => InvokePrepared(() => function, cancellation);
    internal Task<T> InvokePrepared<T>(Func<Func<S, T>> prepare, CancellationToken cancellation = default)
    {
        lock (gate) {
            if (closing) return Task.FromException<T>(new TransitException(ErrorKind.Closed, "admission"));
            if (busy || Thread.CurrentThread == thread) return Task.FromException<T>(new TransitException(ErrorKind.Busy, "admission"));
            if (cancellation.IsCancellationRequested) return Task.FromCanceled<T>(cancellation);
            Func<S, T> function;
            try { function = prepare(); } catch (Exception error) { return Task.FromException<T>(error); }
            TaskCompletionSource<T> completion = new(TaskCreationOptions.RunContinuationsAsynchronously);
            busy = true;
            queue.Add(state => {
                T? value = default; Exception? failure = null;
                try { value = function(state); } catch (Exception error) { failure = error; }
                finally { lock (gate) busy = false; }
                if (failure is null) completion.TrySetResult(value!); else completion.TrySetException(failure);
            });
            return cancellation.CanBeCanceled ? completion.Task.WaitAsync(cancellation) : completion.Task;
        }
    }
    internal void CheckClose()
    {
        if (Thread.CurrentThread == thread) throw new TransitException(ErrorKind.Busy, "callback-close");
    }
    internal Task<E> CloseAsync()
    {
        CheckClose();
        lock (gate) { if (!closing) { closing = true; queue.CompleteAdding(); } }
        return closed.Task;
    }
    internal E CloseSnapshot()
    {
        CheckClose();
        try { return CloseAsync().GetAwaiter().GetResult(); }
        finally { thread.Join(); }
    }
}
