// Inspect actual Linux mappings so per-owner unload fails deterministically,
// even when a detached native worker wins the race to return from its library.
internal static class NativeLifetime
{
    internal static HashSet<string> Mappings() => File.ReadLines("/proc/self/maps")
        .Select(line => line.Split(' ', StringSplitOptions.RemoveEmptyEntries))
        .Where(fields => fields.Length >= 6 && fields[5].Contains("/transit-dotnet-", StringComparison.Ordinal)
            && fields[5].EndsWith(".so", StringComparison.Ordinal))
        .Select(fields => fields[5]).ToHashSet(StringComparer.Ordinal);
    internal static bool Maps(string path) => File.ReadLines("/proc/self/maps")
        .Select(line => line.Split(' ', StringSplitOptions.RemoveEmptyEntries))
        .Any(fields => fields.Length >= 6 && fields[5] == path);
    internal static void Retained(HashSet<string> expected)
    {
        if (expected.Count == 0 || !Mappings().SetEquals(expected)) throw new InvalidOperationException("Native code was unloaded or duplicated");
        if (expected.Any(File.Exists)) throw new InvalidOperationException("Private native extraction remains on disk");
    }
}
