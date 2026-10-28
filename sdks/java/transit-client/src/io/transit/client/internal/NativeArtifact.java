package io.transit.client.internal;

import java.io.*;
import java.nio.file.*;
import java.nio.file.attribute.PosixFilePermissions;
import java.nio.charset.StandardCharsets;

/** Extract one explicitly versioned native artifact; no credentials or work on class load. */
public final class NativeArtifact implements AutoCloseable {
    private final Path directory;
    private final Path executable;
    private NativeArtifact(Path directory, Path executable) { this.directory = directory; this.executable = executable; }
    public Path executable() { return executable; }
    public static NativeArtifact open(String family, Path override) {
        if (override != null) {
            if (!Files.isRegularFile(override) || !Files.isExecutable(override)) throw Values.incompatible("native-path");
            return new NativeArtifact(null, override);
        }
        if (!"Linux".equals(System.getProperty("os.name")) || !"amd64".equals(System.getProperty("os.arch"))) throw Values.incompatible("native-platform");
        String root = "/io/transit/native" + family + "/";
        Path directory = null;
        try (InputStream version = NativeArtifact.class.getResourceAsStream(root + "version");
             InputStream binary = NativeArtifact.class.getResourceAsStream(root + "transit-" + family + "-host")) {
            if (version == null || binary == null || !new String(version.readNBytes(32), StandardCharsets.US_ASCII).equals("0.0.1\n")) throw Values.incompatible("native-artifact-version");
            directory = Files.createTempDirectory("transit-java-native-", PosixFilePermissions.asFileAttribute(PosixFilePermissions.fromString("rwx------")));
            Path executable = directory.resolve("transit-" + family + "-host");
            Files.copy(binary, executable);
            Files.setPosixFilePermissions(executable, PosixFilePermissions.fromString("rwx------"));
            return new NativeArtifact(directory, executable);
        } catch (IOException | RuntimeException error) {
            RuntimeException failure = error instanceof IOException io ? Values.localIo("native-artifact", io) : (RuntimeException) error;
            if (directory != null) {
                try { Files.deleteIfExists(directory.resolve("transit-" + family + "-host")); Files.deleteIfExists(directory); }
                catch (IOException cleanup) { failure.addSuppressed(cleanup); }
            }
            throw failure;
        }
    }
    @Override public void close() {
        if (directory == null) return;
        try { Files.deleteIfExists(executable); Files.deleteIfExists(directory); }
        catch (IOException error) { throw new io.transit.client.TransitException(io.transit.client.TransitException.Kind.CLEANUP, "native-artifact"); }
    }
}
