using System.Reflection;
using System.Runtime.InteropServices;

namespace Transit.Client.Internal;

/// <summary>One native reference per owned worker; no process-wide path selection.</summary>
internal sealed class NativePackage : IDisposable
{
    private readonly string? directory;
    private readonly string? file;
    internal IntPtr Library { get; private set; }
    internal NativePackage(string family, string? overrideDirectory)
    {
        if (!OperatingSystem.IsLinux() || RuntimeInformation.ProcessArchitecture != Architecture.X64) throw Value.Incompatible("native-platform");
        try {
            if (overrideDirectory is not null) {
                Library = NativeLibrary.Load(Path.Combine(overrideDirectory, $"libtransit_{family}.so"));
                return;
            }
            string component = family == "client" ? "Client" : "Station";
            Assembly artifact = Assembly.Load($"Transit.Native.{component}");
            if (artifact.GetCustomAttribute<AssemblyInformationalVersionAttribute>()?.InformationalVersion != "0.2.0") throw Value.Incompatible("native-artifact-version");
            using Stream input = artifact.GetManifestResourceStream($"transit.{family}.native") ?? throw Value.Incompatible("native-artifact-resource");
            directory = Path.Combine(Path.GetTempPath(), "transit-dotnet-" + Guid.NewGuid().ToString("N"));
            Directory.CreateDirectory(directory, UnixFileMode.UserRead | UnixFileMode.UserWrite | UnixFileMode.UserExecute);
            file = Path.Combine(directory, $"libtransit_{family}.so");
            using (FileStream output = new(file, new FileStreamOptions { Mode = FileMode.CreateNew, Access = FileAccess.Write,
                UnixCreateMode = UnixFileMode.UserRead | UnixFileMode.UserWrite })) input.CopyTo(output);
            Library = NativeLibrary.Load(file);
        } catch (Exception) {
            Dispose(); throw Value.Incompatible("native-artifact");
        }
    }
    public void Dispose()
    {
        if (Library != IntPtr.Zero) { NativeLibrary.Free(Library); Library = IntPtr.Zero; }
        try {
            if (file is not null) File.Delete(file);
            if (directory is not null && Directory.Exists(directory)) Directory.Delete(directory);
        } catch (IOException) { throw new TransitException(ErrorKind.Cleanup, "native-artifact-close"); }
    }
}
