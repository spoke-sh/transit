using Transit.Client.Internal;

namespace Transit.Client;

public sealed record ProcessRef
{
    public ulong Realm { get; }
    public ulong Pid { get; }
    public ProcessRef(ulong realm, ulong pid) { Realm = Value.Counter(realm); Pid = Value.Counter(pid); }
}
public sealed record ResourceRef
{
    public ulong Realm { get; }
    public ulong Resource { get; }
    public ResourceRef(ulong realm, ulong resource) { Realm = Value.Counter(realm); Resource = Value.Counter(resource); }
}
public sealed record Credential
{
    public ulong Realm { get; }
    public ulong Principal { get; }
    public string SeedFile { get; }
    public Credential(ulong realm, ulong principal, string seedFile)
    {
        Realm = Value.Counter(realm); Principal = Value.Counter(principal, 0);
        ArgumentException.ThrowIfNullOrWhiteSpace(seedFile);
        SeedFile = Path.GetFullPath(Value.Text(seedFile, 4096));
    }
    public override string ToString() => $"Credential[Realm={Realm}, Principal={Principal}]";
}
public enum Profile { NativeV1 }
public sealed record ClientConfig
{
    public Uri Endpoint { get; }
    internal string NativeEndpoint { get; }
    public Profile Profile { get; }
    public uint TimeoutMillis { get; }
    public string? NativeDirectory { get; }
    public ClientConfig(Uri endpoint, Profile profile, uint timeoutMillis = 5000, string? nativeDirectory = null)
    {
        ArgumentNullException.ThrowIfNull(endpoint);
        if (profile != Profile.NativeV1 || !endpoint.IsAbsoluteUri || endpoint.Scheme is not ("http" or "https") ||
            endpoint.Host.Length == 0 || endpoint.UserInfo.Length != 0 || endpoint.Query.Length != 0 || endpoint.Fragment.Length != 0 ||
            timeoutMillis is < 1 or > 60000) throw new ArgumentException("Select NativeV1, an HTTP endpoint and a bounded timeout");
        // Keep reserved path bytes escaped; shared native transport joins routes.
        NativeEndpoint = Value.Text(endpoint.GetComponents(UriComponents.HttpRequestUrl, UriFormat.UriEscaped), 4096);
        Endpoint = endpoint; Profile = profile; TimeoutMillis = timeoutMillis;
        NativeDirectory = nativeDirectory is null ? null : Path.GetFullPath(nativeDirectory);
    }
}
public sealed record OperationIdentity
{
    public string Sha256 { get; }
    public OperationIdentity(string sha256)
    {
        if (sha256 is null || sha256.Length != 64 || sha256.Any(c => c is not (>= '0' and <= '9') and not (>= 'a' and <= 'f')))
            throw new ArgumentException("Expected a native SHA-256 operation identity");
        Sha256 = sha256;
    }
}
public sealed record AdmissionReceipt
{
    public ulong Position { get; }
    public AdmissionReceipt(ulong position) { Position = Value.Counter(position); }
}
public sealed record MutationReceipt
{
    public ulong Position { get; }
    public MutationReceipt(ulong position) { Position = Value.Counter(position); }
}
public sealed record Capabilities(ulong Realm, ulong ObservedAt, ulong PrincipalSequence, uint PageSize,
    uint MutationsPerTurn, uint OutputsPerTurn, bool RetainedVersions, bool AssociationLookup, bool ScopedRetry, bool Station);
public sealed record Shutdown(AdmissionReceipt? LastAdmission, MutationReceipt? LastMutation);

public sealed class PendingSend : IDisposable
{
    public sealed record Metadata(OperationIdentity Identity, ProcessRef Peer, ulong Principal, ulong Sequence);
    private readonly object gate = new();
    private byte[]? bytes;
    public Metadata Info { get; }
    internal PendingSend(Metadata info, byte[] bytes) { Info = info; this.bytes = Value.Bytes(bytes, Value.MaxBody); }
    public byte[] Export() { lock (gate) return bytes is null ? throw new TransitException(ErrorKind.Closed, "pending") : (byte[])bytes.Clone(); }
    public void Dispose() { lock (gate) bytes = null; }
    public override string ToString() => $"PendingSend[{Info.Identity.Sha256}]";
}
public sealed class PendingMutation : IDisposable
{
    public sealed record Metadata(OperationIdentity Identity, ulong Realm, ulong Principal, ulong Sequence, string Command);
    private readonly object gate = new();
    private byte[]? bytes;
    public Metadata Info { get; }
    internal PendingMutation(Metadata info, byte[] bytes) { Info = info; this.bytes = Value.Bytes(bytes, Value.MaxBody); }
    public byte[] Export() { lock (gate) return bytes is null ? throw new TransitException(ErrorKind.Closed, "pending") : (byte[])bytes.Clone(); }
    public void Dispose() { lock (gate) bytes = null; }
    public override string ToString() => $"PendingMutation[{Info.Identity.Sha256}]";
}
public interface ISendOutcome { }
public interface IMutationOutcome { }
public sealed record Admitted(AdmissionReceipt Receipt) : ISendOutcome;
public sealed record Confirmed(MutationReceipt Receipt) : IMutationOutcome;
public sealed record Rejected(TransitException Error) : ISendOutcome, IMutationOutcome;
public sealed class Uncertain : ISendOutcome, IMutationOutcome
{
    private readonly byte[] bytes;
    public TransitException Error { get; }
    internal Uncertain(byte[] bytes, TransitException error) { this.bytes = Value.Bytes(bytes, Value.MaxBody); Error = error; }
    public byte[] Recovery() => (byte[])bytes.Clone();
    public override string ToString() => $"Uncertain[Status={Error.Status}]";
}
