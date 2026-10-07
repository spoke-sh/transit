defmodule Transit.SdkExamples.TableWork do
  @moduledoc "Bounded application FIFO records, independent of native Table storage."
  alias Transit.Station.Sdk.Key
  alias Transit.SdkExamples.{Initialize, Insert, Update, Delete, QueryServiceCodec}
  @max_input 9_007_199_254_740_991
  @initial 18_446_744_073_709_551_615
  def initial, do: @initial
  def metadata, do: %Key{name: "table.queue", codec: Transit.SdkExamples.TableQueueCodec}

  def work_key(id),
    do: %Key{name: key("table.work.", id), codec: Transit.SdkExamples.TableWorkCodec}

  def outcome_key(id),
    do: %Key{name: key("table.done.", id), codec: Transit.SdkExamples.TableOutcomeCodec}

  defp key(prefix, id) when is_integer(id) and id > 0 and id <= @initial,
    do:
      prefix <> (id |> Integer.to_string(16) |> String.downcase() |> String.pad_leading(16, "0"))

  def encode(:queue, {head, tail, ready})
      when is_integer(head) and head >= 0 and head <= @initial and
             is_integer(tail) and tail >= 0 and tail <= @max_input and is_boolean(ready) and
             head == 0 == (tail == 0) and (head == @initial or head <= tail) and
             (head != @initial or not ready) do
    {:ok, <<"TQM", 1, head::little-64, tail::little-64, if(ready, do: 1, else: 0)>>}
  end

  def encode(:work, {next, command}) when is_integer(next) and next >= 0 and next <= @max_input do
    if match?(%Initialize{}, command) or match?(%Insert{}, command) or match?(%Update{}, command) or
         match?(%Delete{}, command) do
      with {:ok, bytes} <- QueryServiceCodec.encode(command),
           do: {:ok, <<"TQW", 1, next::little-64, bytes::binary>>}
    else
      {:error, :invalid_table_work}
    end
  end

  def encode(:outcome, {state, admitted, completed, matched, changed, rejection})
      when is_integer(state) and state >= 0 and state <= 3 and is_integer(admitted) and
             admitted > 0 and
             is_integer(completed) and completed >= admitted and completed <= @max_input and
             is_integer(matched) and matched >= 0 and matched <= @initial and is_integer(changed) and
             changed >= 0 and changed <= matched and
             is_integer(rejection) and rejection >= 0 and rejection <= 7 and
             (state == 1 or (matched == 0 and changed == 0)) and state == 2 == (rejection != 0) do
    {:ok,
     <<"TQO", 1, state, admitted::little-64, completed::little-64, matched::little-64,
       changed::little-64, rejection>>}
  end

  def encode(_, _), do: {:error, :invalid_table_record}

  def decode(:queue, <<"TQM", 1, head::little-64, tail::little-64, flag>>) when flag <= 1,
    do: checked(:queue, {head, tail, flag == 1})

  def decode(:work, <<"TQW", 1, next::little-64, bytes::binary>>)
      when byte_size(bytes) in [5, 13, 14, 22] do
    with {:ok, command} <- QueryServiceCodec.decode(bytes), do: checked(:work, {next, command})
  end

  def decode(
        :outcome,
        <<"TQO", 1, state, admitted::little-64, completed::little-64, matched::little-64,
          changed::little-64, rejection>>
      ),
      do: checked(:outcome, {state, admitted, completed, matched, changed, rejection})

  def decode(_, _), do: {:error, :malformed_table_record}

  defp checked(kind, value) do
    with {:ok, _} <- encode(kind, value), do: {:ok, value}
  end
end

defmodule Transit.SdkExamples.TableQueueCodec do
  @behaviour Transit.Station.Sdk.Codec
  @impl true
  def type_id, do: "transit.examples.table.queue"
  @impl true
  def version, do: 1
  @impl true
  def max_encoded_bytes, do: 21
  @impl true
  def encode(value), do: Transit.SdkExamples.TableWork.encode(:queue, value)
  @impl true
  def decode(bytes), do: Transit.SdkExamples.TableWork.decode(:queue, bytes)
end

defmodule Transit.SdkExamples.TableWorkCodec do
  @behaviour Transit.Station.Sdk.Codec
  @impl true
  def type_id, do: "transit.examples.table.work"
  @impl true
  def version, do: 1
  @impl true
  def max_encoded_bytes, do: 34
  @impl true
  def encode(value), do: Transit.SdkExamples.TableWork.encode(:work, value)
  @impl true
  def decode(bytes), do: Transit.SdkExamples.TableWork.decode(:work, bytes)
end

defmodule Transit.SdkExamples.TableOutcomeCodec do
  @behaviour Transit.Station.Sdk.Codec
  @impl true
  def type_id, do: "transit.examples.table.outcome"
  @impl true
  def version, do: 1
  @impl true
  def max_encoded_bytes, do: 38
  @impl true
  def encode(value), do: Transit.SdkExamples.TableWork.encode(:outcome, value)
  @impl true
  def decode(bytes), do: Transit.SdkExamples.TableWork.decode(:outcome, bytes)
end
