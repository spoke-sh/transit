namespace Transit.Sdk.Examples;

public interface ICounterMessage { }
public interface IQueryMessage { }
public sealed record Add(ulong Value) : ICounterMessage;
public sealed record Read : ICounterMessage;
public sealed record Start : ICounterMessage, IQueryMessage;
public sealed record Total(ulong Value) : ICounterMessage;
public sealed record Initialize : IQueryMessage;
public sealed record Insert(long Key, long? Value) : IQueryMessage;
public sealed record Rows : IQueryMessage;
