import io.transit.client.Client;
import io.transit.client.ClientConfig;
import io.transit.client.TransitException;
import java.io.IOException;
import java.net.URI;
import java.nio.file.Path;

/** Installed artifacts distinguish unavailable local I/O from incompatible peers. */
public final class JavaNativeStartup {
    private JavaNativeStartup() {}
    public static void main(String[] args) {
        Path override = args.length == 2 ? Path.of(args[1]) : null;
        var config = new ClientConfig(URI.create("http://127.0.0.1:1"),
            ClientConfig.Profile.NATIVE_V1, 3000, override);
        try (var client = Client.open(config)) {
            throw new AssertionError("Startup unexpectedly succeeded: " + client);
        } catch (TransitException error) {
            if (error.kind() != TransitException.Kind.LOCAL_IO || error.status() != -1 ||
                !error.phase().equals(args[0]) || error.rejected() || error.diagnostic() != null ||
                !(error.getCause() instanceof IOException) ||
                !error.code().equals(error.getCause().getClass().getSimpleName()) ||
                error.getMessage().contains("install matching") ||
                !error.getMessage().contains("java.io.tmpdir")) {
                throw new AssertionError("Incorrect startup failure", error);
            }
        }
    }
}
