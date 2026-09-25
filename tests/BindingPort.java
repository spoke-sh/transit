import com.google.gson.JsonObject;
import io.transit.station.NativeHost;
import java.nio.file.*;
import java.util.concurrent.*;

public class BindingPort {
    private static String config(String root, String mode) throws Exception {
        Path path = Path.of(root, mode + ".json"); Files.writeString(path, mode); return path.toString();
    }
    public static void main(String[] args) throws Exception {
        for (String mode : new String[]{"malformed", "oversize", "exit"}) {
            try (var host = NativeHost.open(args[0], config(args[1], mode))) {
                try { host.next().get(3, TimeUnit.SECONDS); throw new AssertionError("Invalid completion accepted"); }
                catch (ExecutionException error) {
                    if (!(error.getCause() instanceof NativeHost.TransitException failure) || failure.status != 6) throw error;
                }
            }
        }
        String stalled = config(args[1], "stall");
        Files.deleteIfExists(Path.of(args[1], "stall.entered"));
        try (var host = NativeHost.open(args[0], stalled)) {
            var pending = host.next();
            long deadline = System.nanoTime() + TimeUnit.SECONDS.toNanos(3);
            while (!Files.exists(Path.of(args[1], "stall.entered"))) {
                if (System.nanoTime() > deadline) throw new AssertionError("No native request");
                Thread.sleep(5);
            }
            try { host.pending().get(); throw new AssertionError("Concurrent operation admitted"); }
            catch (ExecutionException error) {
                if (!(error.getCause() instanceof NativeHost.TransitException failure) || failure.status != 9) throw error;
            }
            if (!pending.cancel(true)) throw new AssertionError("Await not cancellable");
        }
        try (var host = NativeHost.open(args[0], config(args[1], "echo"))) {
            host.request(NativeHost.tag("echo", new JsonObject())).thenApply(value -> {
                try { return host.request(NativeHost.tag("echo", new JsonObject())).get(2, TimeUnit.SECONDS); }
                catch (Exception error) { throw new CompletionException(error); }
            }).get(4, TimeUnit.SECONDS);
        }
        System.out.println("Java: malformed/oversized/lost port, busy admission, cancellation and reentrant continuation passed");
    }
}
