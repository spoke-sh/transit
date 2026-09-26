import com.google.gson.*;
import io.transit.client.*;
import io.transit.client.Outcomes.*;
import io.transit.client.internal.*;
import java.net.URI;
import java.nio.charset.StandardCharsets;
import java.nio.file.*;
import java.util.*;
import java.util.concurrent.*;
import static io.transit.client.internal.Worker.await;

public final class JavaClientSdk {
    private JavaClientSdk() {}
    private static void check(boolean condition) { if (!condition) throw new AssertionError("Public Java SDK proof failed"); }
    private static void expect(TransitException.Kind kind, Runnable action) {
        try { action.run(); }
        catch (TransitException error) { check(error.kind() == kind); return; }
        throw new AssertionError("Expected " + kind);
    }
    private static void invalid(Runnable action) {
        try { action.run(); } catch (IllegalArgumentException error) { return; }
        throw new AssertionError("Expected invalid argument");
    }
    public static void main(String[] args) throws Exception {
        String mode = args[0];
        Path configFile = Path.of(args[1]);
        JsonObject cfg = Values.object(Values.parse(Files.readAllBytes(configFile)));
        Path root = configFile.getParent();
        String location = Client.class.getProtectionDomain().getCodeSource().getLocation().toString();
        check(location.contains(root.toString()) && location.endsWith(".jar"));
        check(Client.class.getResource("/io/transit/nativestation/version") == null);
        ClientConfig config = new ClientConfig(URI.create(cfg.get("url").getAsString()), ClientConfig.Profile.GROWING_V3, 3000, null);
        Credential credential = new Credential(72, 65536, Path.of(cfg.get("seed").getAsString()));
        ProcessRef peer = new ProcessRef(72, cfg.get("pid").getAsLong());
        Path pendingFile = Path.of(cfg.get("pending").getAsString());
        invalid(() -> new ProcessRef(72, 1L << 53));
        invalid(() -> new ResourceRef(72, -1));
        expect(TransitException.Kind.INCOMPATIBLE_NATIVE, () -> Client.open(new ClientConfig(config.endpoint(), config.profile(), 3000, Path.of("/missing-transit"))));
        switch (mode) {
            case "first" -> {
                expect(TransitException.Kind.INCOMPATIBLE_NATIVE, () -> Client.open(new ClientConfig(config.endpoint(), config.profile(), 3000, root.resolve("bad-version"))));
                expect(TransitException.Kind.INCOMPATIBLE_NATIVE, () -> Client.open(new ClientConfig(config.endpoint(), config.profile(), 3000, root.resolve("fractional-version"))));
                JsonObject schemas = Values.obj("Request", Values.obj("type", "object", "properties", Values.obj(), "additionalProperties", false));
                for (String fake : List.of("bad-status", "fractional-status", "huge-status", "bad-utf8", "bad-duplicate", "bad-oversize", "bad-partial")) {
                    for (boolean mutation : List.of(false, true)) {
                        try (Port port = new Port("client", root.resolve(fake), Values.obj(), schemas, "Request")) {
                            expect(mutation ? TransitException.Kind.UNKNOWN_OUTCOME : TransitException.Kind.READ_FAILED,
                                () -> port.request(Values.obj(), "fixture", mutation, null));
                        }
                    }
                }
                try (Client client = Client.open(config)) {
                    Capabilities caps = await(client.capabilities(credential));
                    check(caps.principalSequence() == 0 && caps.pageSize() == 8 && caps.retainedVersions());
                    byte[] payload = "wide".getBytes(StandardCharsets.US_ASCII);
                    try (PendingSend pending = await(client.prepareSend(peer, payload, credential, 1))) {
                        byte[] bytes = pending.export(); payload[0] = 0; pending.export()[0] = 0;
                        check(Arrays.equals(bytes, pending.export()));
                        check(!pending.toString().contains("signature") && !credential.toString().contains(credential.seedFile().toString()));
                        Files.write(pendingFile, bytes);
                        SendOutcome outcome = await(client.dispatch(pending));
                        check(outcome instanceof Uncertain);
                        Uncertain uncertain = (Uncertain) outcome;
                        check(uncertain.error().status() == 6 && Arrays.equals(bytes, uncertain.recovery()));
                    }
                }
            }
            case "recover" -> {
                check(!Files.exists(credential.seedFile()));
                try (Client client = Client.open(config); PendingSend pending = await(client.recoverSend(Files.readAllBytes(pendingFile)))) {
                    AdmissionReceipt receipt = ((Admitted) await(client.dispatch(pending))).receipt();
                    check(await(client.evidence()).lastAdmission().equals(receipt));
                    check(((Admitted) await(client.dispatch(pending))).receipt().equals(receipt));
                    byte[] spawn = Files.readAllBytes(Path.of(cfg.get("spawn").getAsString()));
                    expect(TransitException.Kind.UNSUPPORTED_CAPABILITY, () -> await(client.recoverSend(spawn)));
                    byte[] noncanonical = (" " + Values.text(pending.export())).getBytes(StandardCharsets.UTF_8);
                    try { await(client.recoverSend(noncanonical)); throw new AssertionError("Noncanonical recovery accepted"); }
                    catch (TransitException expected) { }
                    System.out.println(Values.obj("position", receipt.position()));
                }
            }
            case "async" -> {
                try (Client client = Client.open(config); PendingSend pending = await(client.prepareSend(peer, "async".getBytes(StandardCharsets.US_ASCII), credential, 2))) {
                    byte[] bytes = pending.export();
                    CompletableFuture<SendOutcome> dispatch = client.dispatch(pending);
                    long deadline = System.nanoTime() + TimeUnit.SECONDS.toNanos(15);
                    Path accepted = Path.of(cfg.get("accepted").getAsString());
                    while (!Files.exists(accepted)) { check(System.nanoTime() < deadline); Thread.sleep(5); }
                    expect(TransitException.Kind.BUSY, () -> await(client.capabilities(credential)));
                    check(dispatch.cancel(true) && dispatch.isCancelled());
                    CompletableFuture<Shutdown> abandonedClose = client.closeAsync();
                    check(abandonedClose.cancel(true));
                    CompletableFuture<Shutdown> joined = client.closeAsync();
                    int beats = 0;
                    while (!joined.isDone()) { beats++; Thread.sleep(10); }
                    Shutdown evidence = await(joined);
                    check(beats > 5 && evidence.lastAdmission() != null && client.retainedEvidence().equals(evidence));
                    expect(TransitException.Kind.CLOSED, () -> await(client.recoverSend(bytes)));
                    try (Client fresh = Client.open(config); PendingSend retry = await(fresh.recoverSend(bytes))) {
                        check(((Admitted) await(fresh.dispatch(retry))).receipt().equals(evidence.lastAdmission()));
                    }
                    System.out.println(Values.obj("await_cancelled", true, "overlap_rejected", true, "responsive_during_join", beats > 5, "disposed_handle_rejected", true));
                }
            }
            case "denied" -> {
                try (Client client = Client.open(config); PendingSend pending = await(client.recoverSend(Files.readAllBytes(pendingFile)))) {
                    SendOutcome result = await(client.dispatch(pending));
                    check(result instanceof Rejected);
                    TransitException error = ((Rejected) result).error();
                    check(error.kind() == TransitException.Kind.ACCESS_DENIED && error.status() == 4);
                }
            }
            default -> throw new IllegalArgumentException("Unknown proof mode");
        }
    }
}
