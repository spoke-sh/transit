package io.transit.client.internal;

import io.transit.client.TransitException;
import static io.transit.client.TransitException.Kind.*;
import java.util.concurrent.*;
import java.util.function.*;

/** One admitted job, one bounded completion slot, and one reserved close command. */
public final class Worker<S extends Worker.State<E>, E> implements AutoCloseable {
    public interface State<E> extends AutoCloseable {
        E evidence();
        @Override void close();
    }
    private interface Job<S> { void run(S state); }
    private record Publication(Runnable publish, boolean terminal, boolean release) {}
    private final ArrayBlockingQueue<Job<S>> jobs = new ArrayBlockingQueue<>(2);
    private final ArrayBlockingQueue<Publication> publications = new ArrayBlockingQueue<>(1);
    private final Thread nativeThread;
    private final Thread publisher;
    private final CompletableFuture<E> closed = new CompletableFuture<>();
    private boolean busy;
    private boolean closing;
    private volatile E evidence;
    public Worker(Supplier<S> factory) {
        CompletableFuture<Void> ready = new CompletableFuture<>();
        publisher = new Thread(() -> {
            for (;;) {
                Publication item = take(publications);
                if (item.release()) synchronized (this) { busy = false; }
                item.publish().run();
                if (item.terminal()) return;
            }
        }, "transit-completions");
        nativeThread = new Thread(() -> {
            S state;
            try { state = factory.get(); ready.complete(null); }
            catch (Throwable failure) {
                ready.completeExceptionally(failure);
                put(publications, new Publication(() -> {}, true, false));
                return;
            }
            for (;;) {
                Job<S> job = take(jobs);
                if (job == closeJob) {
                    Throwable error = null;
                    try { evidence = state.evidence(); } catch (Throwable failure) { error = failure; }
                    try { state.close(); } catch (Throwable failure) { if (error == null) error = failure; }
                    Throwable outcome = error;
                    put(publications, new Publication(() -> {
                        if (outcome == null) closed.complete(evidence);
                        else closed.completeExceptionally(new TransitException(CLEANUP, "worker-close"));
                    }, true, false));
                    return;
                }
                job.run(state);
            }
        }, "transit-owned-port");
        publisher.start(); nativeThread.start();
        try { await(ready); }
        catch (RuntimeException | Error error) { join(nativeThread); join(publisher); throw error; }
    }
    private final Job<S> closeJob = state -> {};
    public <T> CompletableFuture<T> submit(Function<S, T> work) { return submitPrepared(() -> work); }
    public synchronized <T> CompletableFuture<T> submitPrepared(Supplier<Function<S, T>> prepare) {
        if (closing) return CompletableFuture.failedFuture(new TransitException(CLOSED, "admission"));
        if (busy || Thread.currentThread() == nativeThread) return CompletableFuture.failedFuture(new TransitException(BUSY, "admission"));
        Function<S, T> work;
        try { work = prepare.get(); }
        catch (Throwable error) { return CompletableFuture.failedFuture(error); }
        busy = true;
        CompletableFuture<T> result = new CompletableFuture<>();
        jobs.add(state -> {
            T value = null; Throwable failure = null;
            try { value = work.apply(state); } catch (Throwable error) { failure = error; }
            T completed = value; Throwable error = failure;
            put(publications, new Publication(() -> {
                if (error == null) result.complete(completed); else result.completeExceptionally(error);
            }, false, true));
        });
        return result;
    }
    public void checkClose() {
        if (Thread.currentThread() == nativeThread) throw new TransitException(BUSY, "callback-close");
    }
    public void checkBlockingClose() {
        checkClose();
        if (Thread.currentThread() == publisher) throw new TransitException(BUSY, "completion-close");
    }
    public synchronized CompletableFuture<E> closeAsync() {
        checkClose();
        if (!closing) { closing = true; jobs.add(closeJob); }
        // Cancelling this view cannot cancel ownership or retained close evidence.
        return closed.copy();
    }
    public E retainedEvidence() { return evidence; }
    public E closeSnapshot() {
        checkBlockingClose();
        try { return await(closeAsync()); }
        finally { join(nativeThread); join(publisher); }
    }
    @Override public void close() { closeSnapshot(); }
    public static <T> T await(CompletableFuture<T> future) {
        try { return future.join(); }
        catch (CompletionException failure) {
            if (failure.getCause() instanceof RuntimeException error) throw error;
            if (failure.getCause() instanceof Error error) throw error;
            throw failure;
        }
    }
    private static void join(Thread thread) {
        boolean interrupted = false;
        for (;;) { try { thread.join(); break; } catch (InterruptedException error) { interrupted = true; } }
        if (interrupted) Thread.currentThread().interrupt();
    }
    private static <T> T take(BlockingQueue<T> queue) {
        boolean interrupted = false;
        try { for (;;) { try { return queue.take(); } catch (InterruptedException error) { interrupted = true; } } }
        finally { if (interrupted) Thread.currentThread().interrupt(); }
    }
    private static <T> void put(BlockingQueue<T> queue, T value) {
        boolean interrupted = false;
        try { for (;;) { try { queue.put(value); return; } catch (InterruptedException error) { interrupted = true; } } }
        finally { if (interrupted) Thread.currentThread().interrupt(); }
    }
}
