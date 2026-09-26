defmodule Transit.SdkExamples.Codec do
  alias Transit.SdkExamples.{Add, Total, Read, Start, Initialize, Insert, Rows}

  defguardp u64(value)
            when is_integer(value) and value >= 0 and value <= 18_446_744_073_709_551_615

  defguardp i64(value)
            when is_integer(value) and value >= -9_223_372_036_854_775_808 and
                   value <= 9_223_372_036_854_775_807

  def encode(:u64, value) when u64(value), do: {:ok, <<"TSU", 1, value::little-unsigned-64>>}

  def encode(:counter, %Add{value: value}) when u64(value),
    do: {:ok, <<"TSC", 1, 1, value::little-unsigned-64>>}

  def encode(:counter, %Read{}), do: {:ok, <<"TSC", 1, 2>>}
  def encode(:counter, %Start{}), do: {:ok, <<"TSC", 1, 3>>}

  def encode(:counter, %Total{value: value}) when u64(value),
    do: {:ok, <<"TSC", 1, 4, value::little-unsigned-64>>}

  def encode(:query, %Initialize{}), do: {:ok, <<"TSQ", 1, 1>>}

  def encode(:query, %Insert{key: key, value: nil}) when i64(key),
    do: {:ok, <<"TSQ", 1, 2, key::little-signed-64, 0>>}

  def encode(:query, %Insert{key: key, value: value}) when i64(key) and i64(value),
    do: {:ok, <<"TSQ", 1, 2, key::little-signed-64, 1, value::little-signed-64>>}

  def encode(:query, %Rows{}), do: {:ok, <<"TSQ", 1, 3>>}
  def encode(:query, %Start{}), do: {:ok, <<"TSQ", 1, 4>>}
  def encode(_, _), do: {:error, :invalid_application_value}
  def decode(:u64, <<"TSU", 1, value::little-unsigned-64>>), do: {:ok, value}
  def decode(:counter, <<"TSC", 1, 1, value::little-unsigned-64>>), do: {:ok, %Add{value: value}}
  def decode(:counter, <<"TSC", 1, 2>>), do: {:ok, %Read{}}
  def decode(:counter, <<"TSC", 1, 3>>), do: {:ok, %Start{}}

  def decode(:counter, <<"TSC", 1, 4, value::little-unsigned-64>>),
    do: {:ok, %Total{value: value}}

  def decode(:query, <<"TSQ", 1, 1>>), do: {:ok, %Initialize{}}

  def decode(:query, <<"TSQ", 1, 2, key::little-signed-64, 0>>),
    do: {:ok, %Insert{key: key, value: nil}}

  def decode(:query, <<"TSQ", 1, 2, key::little-signed-64, 1, value::little-signed-64>>),
    do: {:ok, %Insert{key: key, value: value}}

  def decode(:query, <<"TSQ", 1, 3>>), do: {:ok, %Rows{}}
  def decode(:query, <<"TSQ", 1, 4>>), do: {:ok, %Start{}}
  def decode(_, _), do: {:error, :malformed_application_payload}
  def allowed(:counter, %Add{}), do: true
  def allowed(:counter, %Read{}), do: true
  def allowed(:requester, %Start{}), do: true
  def allowed(:requester, %Total{}), do: true
  def allowed(:reply, %Total{}), do: true
  def allowed(:query_service, %Initialize{}), do: true
  def allowed(:query_service, %Insert{}), do: true
  def allowed(:query_service, %Rows{}), do: true
  def allowed(:query_requester, %Start{}), do: true
  def allowed(:u64, value) when u64(value), do: true
  def allowed(_, _), do: false
end

defmodule Transit.SdkExamples.CounterCodec do
  @behaviour Transit.Station.Sdk.Codec
  alias Transit.SdkExamples.Codec
  @impl true
  def type_id, do: "transit.examples.counter"
  @impl true
  def version, do: 1
  @impl true
  def max_encoded_bytes, do: 13
  @impl true
  def encode(value),
    do:
      if(Codec.allowed(:counter, value),
        do: Codec.encode(:counter, value),
        else: {:error, :unsupported_role}
      )

  @impl true
  def decode(bytes) do
    with {:ok, value} <- Codec.decode(:counter, bytes) do
      if Codec.allowed(:counter, value), do: {:ok, value}, else: {:error, :unsupported_role}
    end
  end
end

defmodule Transit.SdkExamples.RequesterCodec do
  @behaviour Transit.Station.Sdk.Codec
  alias Transit.SdkExamples.Codec
  @impl true
  def type_id, do: "transit.examples.counter"
  @impl true
  def version, do: 1
  @impl true
  def max_encoded_bytes, do: 13
  @impl true
  def encode(value),
    do:
      if(Codec.allowed(:requester, value),
        do: Codec.encode(:counter, value),
        else: {:error, :unsupported_role}
      )

  @impl true
  def decode(bytes) do
    with {:ok, value} <- Codec.decode(:counter, bytes) do
      if Codec.allowed(:requester, value), do: {:ok, value}, else: {:error, :unsupported_role}
    end
  end
end

defmodule Transit.SdkExamples.ReplyCodec do
  @behaviour Transit.Station.Sdk.Codec
  alias Transit.SdkExamples.Codec
  @impl true
  def type_id, do: "transit.examples.counter"
  @impl true
  def version, do: 1
  @impl true
  def max_encoded_bytes, do: 13
  @impl true
  def encode(value),
    do:
      if(Codec.allowed(:reply, value),
        do: Codec.encode(:counter, value),
        else: {:error, :unsupported_role}
      )

  @impl true
  def decode(bytes) do
    with {:ok, value} <- Codec.decode(:counter, bytes) do
      if Codec.allowed(:reply, value), do: {:ok, value}, else: {:error, :unsupported_role}
    end
  end
end

defmodule Transit.SdkExamples.QueryServiceCodec do
  @behaviour Transit.Station.Sdk.Codec
  alias Transit.SdkExamples.Codec
  @impl true
  def type_id, do: "transit.examples.query"
  @impl true
  def version, do: 1
  @impl true
  def max_encoded_bytes, do: 22
  @impl true
  def encode(value),
    do:
      if(Codec.allowed(:query_service, value),
        do: Codec.encode(:query, value),
        else: {:error, :unsupported_role}
      )

  @impl true
  def decode(bytes) do
    with {:ok, value} <- Codec.decode(:query, bytes) do
      if Codec.allowed(:query_service, value), do: {:ok, value}, else: {:error, :unsupported_role}
    end
  end
end

defmodule Transit.SdkExamples.QueryRequesterCodec do
  @behaviour Transit.Station.Sdk.Codec
  alias Transit.SdkExamples.Codec
  @impl true
  def type_id, do: "transit.examples.query"
  @impl true
  def version, do: 1
  @impl true
  def max_encoded_bytes, do: 22
  @impl true
  def encode(value),
    do:
      if(Codec.allowed(:query_requester, value),
        do: Codec.encode(:query, value),
        else: {:error, :unsupported_role}
      )

  @impl true
  def decode(bytes) do
    with {:ok, value} <- Codec.decode(:query, bytes) do
      if Codec.allowed(:query_requester, value),
        do: {:ok, value},
        else: {:error, :unsupported_role}
    end
  end
end

defmodule Transit.SdkExamples.U64Codec do
  @behaviour Transit.Station.Sdk.Codec
  alias Transit.SdkExamples.Codec
  @impl true
  def type_id, do: "transit.examples.u64"
  @impl true
  def version, do: 1
  @impl true
  def max_encoded_bytes, do: 12
  @impl true
  def encode(value),
    do:
      if(Codec.allowed(:u64, value),
        do: Codec.encode(:u64, value),
        else: {:error, :unsupported_role}
      )

  @impl true
  def decode(bytes) do
    with {:ok, value} <- Codec.decode(:u64, bytes) do
      if Codec.allowed(:u64, value), do: {:ok, value}, else: {:error, :unsupported_role}
    end
  end
end
