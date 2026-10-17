using System.Reflection;
using System.Runtime.InteropServices;
using System.Security.Cryptography;

namespace Transit.Client.Internal;

/// <summary>Bounded shared code images; native handles remain owned by each worker.</summary>
internal sealed class NativePackage : IDisposable
{
    // The pinned Zig I/O pool signals completion before detached threads finish
    // returning through native code. Destroying handles does not permit dlclose.
    private const int MaximumImages = 16;
    private sealed class Loaded(string? digest)
    {
        internal IntPtr Library;
        internal readonly string? Digest = digest;
    }
    private static readonly Dictionary<string, Loaded> Images = new(MaximumImages, StringComparer.Ordinal);
    internal IntPtr Library { get; private set; }
    internal NativePackage(string family, string? overrideDirectory)
    {
        if (!OperatingSystem.IsLinux() || RuntimeInformation.ProcessArchitecture != Architecture.X64) throw Value.Incompatible("native-platform");
        try {
            if (overrideDirectory is not null) {
                string path = Path.GetFullPath(Path.Combine(overrideDirectory, $"libtransit_{family}.so"));
                lock (Images) {
                    string digest = Digest(path);
                    string key = "file:" + path;
                    if (Images.TryGetValue(key, out var existing)) {
                        if (existing.Digest != digest) throw Value.Incompatible("native-file-changed");
                        Library = existing.Library;
                        return;
                    }
                    CheckCapacity();
                    var loaded = new Loaded(digest);
                    loaded.Library = NativeLibrary.Load(path);
                    Images.Add(key, loaded);
                    if (Digest(path) != digest) throw Value.Incompatible("native-file-changed");
                    Library = loaded.Library;
                }
                return;
            }
            string component = family == "client" ? "Client" : "Station";
            Assembly artifact = Assembly.Load($"Transit.Native.{component}");
            if (artifact.GetCustomAttribute<AssemblyInformationalVersionAttribute>()?.InformationalVersion != "0.2.0") throw Value.Incompatible("native-artifact-version");
            string embedded = $"embedded:{artifact.ManifestModule.ModuleVersionId}:{family}";
            lock (Images) {
                if (Images.TryGetValue(embedded, out var existing)) { Library = existing.Library; return; }
                CheckCapacity();
                using Stream input = artifact.GetManifestResourceStream($"transit.{family}.native") ?? throw Value.Incompatible("native-artifact-resource");
                string directory = Path.Combine(Path.GetTempPath(), "transit-dotnet-" + Guid.NewGuid().ToString("N"));
                Directory.CreateDirectory(directory, UnixFileMode.UserRead | UnixFileMode.UserWrite | UnixFileMode.UserExecute);
                string file = Path.Combine(directory, $"libtransit_{family}.so");
                try {
                    using (FileStream output = new(file, new FileStreamOptions { Mode = FileMode.CreateNew, Access = FileAccess.Write,
                        UnixCreateMode = UnixFileMode.UserRead | UnixFileMode.UserWrite })) input.CopyTo(output);
                    var loaded = new Loaded(null);
                    loaded.Library = NativeLibrary.Load(file);
                    Images.Add(embedded, loaded);
                    Library = loaded.Library;
                } finally {
                    File.Delete(file);
                    Directory.Delete(directory);
                }
            }
        } catch (Exception) {
            Dispose(); throw Value.Incompatible("native-artifact");
        }
    }
    private static string Digest(string path)
    {
        using FileStream input = File.OpenRead(path);
        return Convert.ToHexString(SHA256.HashData(input));
    }
    private static void CheckCapacity()
    {
        if (Images.Count == MaximumImages) throw Value.Incompatible("native-library-capacity");
    }
    public void Dispose() => Library = IntPtr.Zero;
}
