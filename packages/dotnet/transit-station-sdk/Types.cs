using Transit.Client;
using Transit.Client.Internal;

namespace Transit.Station.Sdk;

public interface ICodec<T> where T : notnull
{
    string TypeId { get; }
    uint Version { get; }
    int MaxEncodedBytes { get; }
    byte[] Encode(T value);
    T Decode(byte[] bytes);
}
public sealed class Bytes : IEquatable<Bytes>
{
    private readonly byte[] bytes;
    public Bytes(byte[] bytes) { this.bytes = Value.Bytes(bytes, Value.MaxBody); }
    public int Length => bytes.Length;
    public byte[] Copy() => (byte[])bytes.Clone();
    public bool Equals(Bytes? other) => other is not null && bytes.AsSpan().SequenceEqual(other.bytes);
    public override bool Equals(object? other) => other is Bytes value && Equals(value);
    public override int GetHashCode() { HashCode hash = new(); hash.AddBytes(bytes); return hash.ToHashCode(); }
    public override string ToString() => $"Bytes[Length={bytes.Length}]";
}
public sealed class Key<T> where T : notnull
{
    public Bytes Name { get; }
    public ICodec<T> Codec { get; }
    public Key(byte[] name, ICodec<T> codec)
    {
        ArgumentNullException.ThrowIfNull(name); ArgumentNullException.ThrowIfNull(codec);
        if (name.Length == 0 || name[0] == 0) throw new ArgumentException("Use a nonempty application key outside the reserved prefix");
        Name = new Bytes(name); Codec = codec;
    }
    public Key(string name, ICodec<T> codec) : this(Value.Utf8.GetBytes(Value.Text(name, Value.MaxBody)), codec) { }
    public override string ToString() => "Key[application codec]";
}
public enum FailurePolicy { Stop, BlockInput }
public sealed record Activation
{
    public ProcessRef Process { get; }
    public ulong Generation { get; }
    public Credential Credential { get; }
    public Activation(ProcessRef process, ulong generation, Credential credential)
    {
        ArgumentNullException.ThrowIfNull(process); ArgumentNullException.ThrowIfNull(credential);
        if (process.Realm != credential.Realm) throw new ArgumentException("Activation realm mismatch");
        Process = process; Generation = Value.Counter(generation); Credential = credential;
    }
}
public sealed record ServiceConfig
{
    public ClientConfig Client { get; }
    public Activation Activation { get; }
    public string Association { get; }
    public bool QueryResults { get; }
    public ServiceConfig(ClientConfig client, Activation activation, string association = "data", bool queryResults = false)
    {
        ArgumentNullException.ThrowIfNull(client); ArgumentNullException.ThrowIfNull(activation); ArgumentException.ThrowIfNullOrEmpty(association);
        Client = client; Activation = activation; Association = Value.Text(association, 256); QueryResults = queryResults;
    }
}
public sealed record WaitPolicy
{
    public ulong? DeadlineMillis { get; }
    public ProcessRef? Observer { get; }
    private WaitPolicy(ulong? deadline, ProcessRef? observer) { DeadlineMillis = deadline; Observer = observer; }
    public static WaitPolicy Untimed { get; } = new(null, null);
    public static WaitPolicy Until(ulong deadline, ProcessRef observer)
    {
        ArgumentNullException.ThrowIfNull(observer); return new(Value.Counter(deadline), observer);
    }
}
public abstract record Origin;
public sealed record ExternalOrigin(ulong Principal, ulong PolicyRevision) : Origin;
public sealed record ProcessOrigin(ProcessRef Process, ulong Turn, ulong Output) : Origin;
public sealed record EffectOrigin(ulong Effect, ulong Attempt, ulong Executor) : Origin;
public abstract record Incoming<T>(T Value, ulong Position, Origin Origin) where T : notnull;
public sealed record Cast<T>(T Value, ulong Position, Origin Origin) : Incoming<T>(Value, Position, Origin) where T : notnull;
public sealed record Call<T>(T Value, ulong Position, Origin Origin, ulong Correlation) : Incoming<T>(Value, Position, Origin) where T : notnull;
public sealed record Reply<T>(T Value, ulong Position, Origin Origin, ulong Correlation) : Incoming<T>(Value, Position, Origin) where T : notnull;
public enum ControlKind { Cancel, Timeout }
public sealed record Control(ControlKind Kind, ulong Position, Origin Origin, ulong Correlation);
public sealed record ResultComplete(ulong Position, Origin Origin, ulong Correlation);
public sealed record Budgets(uint Mutations, uint Outputs, uint Views, uint RetainedReads, uint Retains, uint Releases);
public sealed record ReadVersion
{
    public ulong Pid { get; }
    public ulong Input { get; }
    public byte Index { get; }
    public ReadVersion(ulong pid, ulong input, byte index) { Pid = Value.Counter(pid); Input = Value.Counter(input); Index = index; }
}
public sealed record Cursor
{
    public string Opaque { get; }
    public Cursor(string opaque) { Opaque = Value.Text(opaque, Value.MaxBody); }
}
public sealed record Basis(ResourceRef Resource, ulong Revision, Bytes Schema);
public sealed class Page<T>
{
    public IReadOnlyList<T> Entries { get; }
    public Cursor? Cursor { get; }
    public Basis? Basis { get; }
    internal Page(IEnumerable<T> entries, Cursor? cursor, Basis? basis) { Entries = Array.AsReadOnly(entries.ToArray()); Cursor = cursor; Basis = basis; }
}
public sealed record KVEntry(Bytes Key, Bytes Value, ulong Revision);
public sealed record Found<T>(T Value) where T : notnull;
public enum Purpose { Permit, Open, Commit }
public sealed record FrozenMutation(OperationIdentity Identity, Purpose Purpose, ulong InputPosition, Bytes Bytes)
{
    public byte[] Export() => Bytes.Copy();
    public override string ToString() => $"FrozenMutation[{Purpose}, {Identity.Sha256}]";
}
public abstract record RunnerEvent;
public sealed record Committed(ulong Input, MutationReceipt Receipt) : RunnerEvent;
public sealed record Blocked(ulong? Input, MutationReceipt? Receipt) : RunnerEvent;
public sealed record NeedsRecovery(FrozenMutation Mutation, string Phase, TransitException Error, MutationReceipt? Receipt) : RunnerEvent;
public sealed record Idle : RunnerEvent;
public sealed record Progress : RunnerEvent;
public sealed record Stopped : RunnerEvent;
public sealed record RunnerShutdown(FrozenMutation? Pending, RunnerEvent? LastEvent);
public sealed class StopToken
{
    private int stopped;
    public void Stop() => Volatile.Write(ref stopped, 1);
    public bool Stopped => Volatile.Read(ref stopped) != 0;
}
public interface IHandler<T> where T : notnull
{
    void Initialize(Turn turn) { }
    void OnMessage(Turn turn, Incoming<T> input);
    void OnControl(Turn turn, Control input) => throw new TransitException(ErrorKind.Handler, "unhandled-control");
    void OnResult(Turn turn, ResultComplete input) => throw new TransitException(ErrorKind.Handler, "unhandled-result");
}
public interface IRecoveryStore
{
    void BeforeDispatch(FrozenMutation mutation);
    void Confirmed(OperationIdentity identity, MutationReceipt receipt);
}
public abstract record Recovery
{
    private protected Recovery() { }
    public sealed record FreshOwnership : Recovery;
    public sealed record PersistBeforeDispatch : Recovery
    {
        public IRecoveryStore Store { get; }
        public PersistBeforeDispatch(IRecoveryStore store) { ArgumentNullException.ThrowIfNull(store); Store = store; }
    }
}
